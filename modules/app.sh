#!/usr/bin/bash

chooseApp() {
    fetchAssetsInfo || return 1
    fetchAssets || return 1
    PREVIOUS_PKG="$PKG_NAME"
    PKG_NAME=$("${DIALOG[@]}" \
        --title '| App Selection Menu |' \
        --no-tags \
        --ok-label 'Select' \
        --cancel-label 'Back' \
        --help-button \
        --help-label 'Import' \
        --default-item "$SELECTED_APP" \
        --menu "$NAVIGATION_HINT" -1 -1 0 \
        "${APPS_LIST[@]}" \
        2>&1 > /dev/tty
    )
    EXIT_CODE=$?
    case "$EXIT_CODE" in
    0)
        source <(jq -nrc --arg PKG_NAME "$PKG_NAME" --argjson APPS_INFO "$APPS_INFO" '$APPS_INFO[] | select(.pkgName == $PKG_NAME) | "APP_NAME=" + .appName + " APKMIRROR_APP_NAME=" + .apkmirrorAppName + " DEVELOPER_NAME=" + .developerName')
        APP_SRC="remote"
        ;;
    1)
        return 1
        ;;
    2)
        APP_SRC="local"
        unset APP_NAME APP_VER
        ;;
    esac
    unset EXIT_CODE
    [ "$PREVIOUS_PKG" != "$PKG_NAME" ] && unset VERSIONS_LIST
}

installApp() {
    if [ "$ROOT_ACCESS" == true ]; then
        mountApp
    else
        notify info "Copying patched $APP_NAME apk to Internal Storage..."
        CANONICAL_VER=${APP_VER//:/}
        cp -f "apps/$APP_NAME/$APP_VER-$SOURCE.apk" "$STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk" &> /dev/null
        termux-open --view "$STORAGE/Patched/$APP_NAME-$CANONICAL_VER-$SOURCE.apk"
    fi
}
