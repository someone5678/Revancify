#!/usr/bin/bash

SRC=$(dirname "$0")
ROOT_ACCESS="$1"

initConfig() {
    setEnv LIGHT_THEME "off" init .config
    setEnv PREFER_SPLIT_APK "on" init .config
    setEnv LAUNCH_APP_AFTER_MOUNT "on" init .config
    setEnv ALLOW_APP_VERSION_DOWNGRADE "off" init .config
    setEnv FETCH_PRE_RELEASE "off" init .config
    setEnv SOURCE "ReVanced" init .config
    source .config
}

main() {

    mkdir -p "$STORAGE" "$STORAGE/Patched" "$STORAGE/Stock"
    mkdir -p apps

    [ "$ROOT_ACCESS" == true ] && MENU_ENTRY=(6 "Uninstall Patched app")

    [ "$LIGHT_THEME" == "on" ] && THEME="LIGHT" || THEME="DARK"
    export DIALOGRC="$SRC/config/.DIALOGRC_$THEME"

    if [ -e $SRC/data/.config ]; then
        source $SRC/data/.config
    else
        initConfig
    fi

    if [ -e $SRC/data/$SOURCE.assets ]; then
        source $SRC/data/$SOURCE.assets
    else
        fetchAssetsInfo
    fi

    while true; do
        unset APP_VER APP_NAME PKG_NAME VERSIONS_LIST
        MAIN=$("${DIALOG[@]}" \
            --title '| Main Menu |' \
            --default-item "$mainMenu" \
            --ok-label 'Select' \
            --cancel-label 'Exit' \
            --menu "$NAVIGATION_HINT" -1 -1 0 1 "Patch App" 2 "Update Assets" 3 "Change Source" 4 "Preferences" 5 "Delete Assets" "${MENU_ENTRY[@]}" \
            2>&1 > /dev/tty
        ) || break
        case "$MAIN" in
        1 )
            TASK="CHOOSE_APP"
            initiateWorkflow
            ;;
        2 )
            fetchAssetsInfo || break
            fetchAssets
            ;;
        3 )
            changeSource
            ;;
        4 )
            preferences
            ;;
        5 )
            deleteAssets
            ;;
        6 )
            umountApp
            ;;
        esac
    done
}

for MODULE in $(find "$SRC/modules" -type f -name "*.sh"); do
    source "$MODULE"
done

initConfig
trap terminate SIGTERM SIGINT SIGABRT
main
terminate "$?"
