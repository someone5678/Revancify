#!/usr/bin/bash

fetchAssetsInfo() {
    unset CLI_STABLE CLI_VERSION CLI_FILE_URL CLI_FILE_SIZE PATCHES_STABLE PATCHES_VERSION PATCHES_FILE_URL PATCHES_FILE_SIZE JSON_URL
    local SOURCE_INFO VERSION PATCHES_API_URL

    source .config

    internet || return 1
    
    if [ "$("${CURL[@]}" "https://api.github.com/rate_limit" | jq -r '.resources.core.remaining')" -gt 5 ]; then

        rm "$SOURCE".assets 2> /dev/null
    
        notify info "Fetching Assets Info..."

        source <(jq -r --arg SOURCE "$SOURCE" '
            .[] | select(.source == $SOURCE) |
            "REPO=\(.repository)",
            (
                .api // empty |
                (
                    (.json // empty | "JSON_URL=\(.)"),
                    (.version // empty | "VERSION_URL=\(.)")
                )
            ),
            "CLI_REPO=\(.cli)"
            ' "$SRC/sources.json"
        )

        [ "$FETCH_PRE_RELEASE" == "off" ] && CLI_STABLE="/latest" || CLI_STABLE=""
        if ! source <("${CURL[@]}" "https://api.github.com/repos/$CLI_REPO/releases$CLI_STABLE" | jq -r '
                if type == "array" then .[0] else . end |
                "CLI_VERSION="+.tag_name,
                (
                    .assets[] |
                    if .content_type == "application/java-archive" then
                        "CLI_FILE_URL="+.browser_download_url,
                        "CLI_FILE_SIZE="+(.size|tostring)
                    else
                        empty
                    end
                )
            '
        ); then
            notify msg "Unable to fetch latest CLI info from API!!\n Retry later."
        fi

        if [ -z $VERSION_URL ]; then
            [ "$FETCH_PRE_RELEASE" == "off" ] && PATCHES_STABLE="/latest" || PATCHES_STABLE=""
            PATCHES_API_URL="https://api.github.com/repos/$REPO/releases$PATCHES_STABLE"
        elif [ -n "$VERSION_URL" ] && VERSION=$("${CURL[@]}" "$VERSION_URL" | jq -r '.version' 2> /dev/null); then
            [ "$FETCH_PRE_RELEASE" == "off" ] && PATCHES_STABLE="/tags/$VERSION" || PATCHES_STABLE=""
            PATCHES_API_URL="https://api.github.com/repos/$REPO/releases$PATCHES_STABLE"
        else
            [ "$FETCH_PRE_RELEASE" == "off" ] && PATCHES_STABLE="/latest" || PATCHES_STABLE=""
            PATCHES_API_URL="https://api.github.com/repos/$REPO/releases$PATCHES_STABLE"
        fi

        if [ -z $JSON_URL ]; then
            JSON_URL=""
        fi

        if ! source <("${CURL[@]}" "$PATCHES_API_URL" | jq -r '
                if type == "array" then .[0] else . end |
                "PATCHES_VERSION="+.tag_name,
                (
                    .assets[] |
                    if (.name | endswith(".rvp")) then
                        "PATCHES_FILE_URL="+.browser_download_url,
                        "PATCHES_FILE_SIZE="+(.size|tostring)
                    else
                        empty
                    end
                )
            '
        ); then
            notify msg "Unable to fetch latest CLI info from API!!\n Retry later."
        fi

        setEnv SOURCE "$SOURCE" init $SOURCE.assets
        setEnv CLI_VERSION "$CLI_VERSION" init $SOURCE.assets
        setEnv CLI_FILE_URL "$CLI_FILE_URL" init $SOURCE.assets
        setEnv CLI_FILE_SIZE "$CLI_FILE_SIZE" init $SOURCE.assets
        setEnv PATCHES_VERSION "$PATCHES_VERSION" init $SOURCE.assets
        setEnv PATCHES_FILE_URL "$PATCHES_FILE_URL" init $SOURCE.assets
        setEnv PATCHES_FILE_SIZE "$PATCHES_FILE_SIZE" init $SOURCE.assets
        [ -n "$JSON_URL" ] && setEnv JSON_URL "$JSON_URL" init $SOURCE.assets
    else
        notify msg "Unable to check for update.\nYou are probably rate-limited at this moment.\nTry again later or Run again with '-o' argument."
        return 1
    fi
    source $SOURCE.assets
}

fetchAssets() {
    local CTR

    if [ -z "$CLI_VERSION" ] && [ -z "$PATCHES_VERSION" ]; then
        fetchAssetsInfo || return 1
    fi

    CLI_FILE_NAME="$SOURCE-cli-$CLI_VERSION.jar"
    [ -e "$CLI_FILE_NAME" ] || rm -- "$SOURCE"-cli-* &> /dev/null

    CTR=2 && while [ "$CLI_FILE_SIZE" != "$(stat -c%s "$CLI_FILE_NAME" 2> /dev/null)" ]; do
        [ $CTR -eq 0 ] && notify msg "Oops! Unable to download completely.\n\nRetry or change your Network." && return 1
        ((CTR--))
        "${WGET[@]}" "$CLI_FILE_URL" -O "$CLI_FILE_NAME" |& stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' |
        "${DIALOG[@]}" --gauge "File    : $CLI_FILE_NAME\nSize    : $(numfmt --to=iec --format="%0.1f" "$CLI_FILE_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c%s "$CLI_FILE_NAME" 2> /dev/null || echo 0) * 100)) / CLI_FILE_SIZE))"
        tput civis
    done

    PATCHES_FILE_NAME="$SOURCE-patches-$PATCHES_VERSION.rvp"
    [ -e "$PATCHES_FILE_NAME" ] || rm -- "$SOURCE"-patches-* &> /dev/null

    CTR=2 && while [ "$PATCHES_FILE_SIZE" != "$(stat -c%s "$PATCHES_FILE_NAME" 2> /dev/null)" ]; do
        [ $CTR -eq 0 ] && notify msg "Oops! Unable to download completely.\n\nRetry or change your Network." && return 1
        ((CTR--))
        "${WGET[@]}" "$PATCHES_FILE_URL" -O "$PATCHES_FILE_NAME" |& stdbuf -o0 cut -b 63-65 | stdbuf -o0 grep '[0-9]' |
        "${DIALOG[@]}" --gauge "File    : $PATCHES_FILE_NAME\nSize    : $(numfmt --to=iec --format="%0.1f" "$PATCHES_FILE_SIZE")\n\nDownloading..." -1 -1 "$(($(($(stat -c%s "$PATCHES_FILE_NAME" 2> /dev/null || echo 0) * 100)) / PATCHES_FILE_SIZE))"
        tput civis
    done

    parsePatchesJson || return 1
}

deleteAssets() {

    if "${DIALOG[@]}" \
            --title '| Delete Tools |' \
            --defaultno \
            --yesno "Please confirm to delete the assets.\nIt will delete the CLI and "$SOURCE" patches." -1 -1\
    ; then
        unset CLI_VERSION CLI_FILE_URL CLI_FILE_SIZE PATCHES_VERSION PATCHES_FILE_URL PATCHES_FILE_SIZE JSON_URL
        rm "$SOURCE".assets &> /dev/null
        rm "$SOURCE"-cli-*.jar &> /dev/null
        rm "$SOURCE"-patches-*.rvp &> /dev/null
    fi
}
