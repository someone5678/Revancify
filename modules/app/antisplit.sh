#!/usr/bin/bash

antisplitApp() {
    local APP_DIR LOCALE

    notify info "Please Wait !!\nMerging split apks..."

    APP_DIR="apps/$APP_NAME/$APP_VER"
    if [ ! -e "$APP_DIR" ]; then
        unzip -qqo "apps/$APP_NAME/$APP_VER.apkm" -d "$APP_DIR"
        rm "apps/$APP_NAME/$APP_VER.apkm"
    fi
    java -jar bin/APKEditor.jar m -i "$APP_DIR" -o "apps/$APP_NAME/$APP_VER.apk" &> /dev/null
    if [ ! -e "apps/$APP_NAME/$APP_VER.apk" ]; then
        notify msg "Unable to run merge splits!!\nApkEditor is not working properly."
        return 1
    fi
    if [ "$ROOT_ACCESS" == false ]; then
        rm -rf "apps/$APP_NAME/$APP_VER"
    fi
    setEnv "APP_SIZE" "$(stat -c %s "apps/$APP_NAME/$APP_VER.apk")" update "apps/$APP_NAME/.data"
}
