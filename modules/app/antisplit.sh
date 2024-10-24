#!/usr/bin/bash

antisplitApp() {
    [ "$APP_FORMAT" == "BUNDLE" ] || return 0

    notify info "Please Wait !!\nMerging split apks..."
    unzip -qqo "apps/$APP_NAME/$APP_VER.apkm" -d "$APP_DIR"
    rm "apps/$APP_NAME/$APP_VER.apkm"
    java -jar ApkEditor.jar m -i "$APP_DIR" -o "apps/$APP_NAME/$APP_VER.apk" &> /dev/null
    setEnv "APP_SIZE" "$(stat -c%s "apps/$APP_NAME/$APP_VER.apk")" update "apps/$APP_NAME/.info"
    unset APP_DIR
}
