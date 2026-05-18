#!/bin/bash

LANG_SHORT="${LANG%%_*}"
LANG_SHORT="${LANG_SHORT%%.*}"

msg() {
  KEY="$1"
  shift || true

  case "$LANG_SHORT" in
    de)
      case "$KEY" in
        build_start)      echo "🔧 Baue Paket: $1" ;;
        package_created)  echo "✅ Paket erstellt: $1" ;;
        publish_start)    echo "📤 Veröffentliche Paket: $1" ;;
        publish_done)     echo "✅ Veröffentlichung abgeschlossen." ;;
        remove_start)     echo "🧹 Entferne Paket aus dem Repository: $1" ;;
        purge_start)      echo "🗑 Entferne Paket vollständig: $1" ;;
        purge_done)       echo "✅ Bereinigung abgeschlossen." ;;
        no_package)       echo "❌ Kein Paket gefunden: $1" ;;
        available_pkgs)   echo "📦 Verfügbare Pakete:" ;;
        *)                echo "$KEY $*" ;;
      esac
      ;;

    hu)
      case "$KEY" in
        build_start)      echo "🔧 Csomag építése: $1" ;;
        package_created)  echo "✅ Csomag elkészült: $1" ;;
        publish_start)    echo "📤 Csomag publikálása: $1" ;;
        publish_done)     echo "✅ Publikálás kész." ;;
        remove_start)     echo "🧹 Csomag eltávolítása a repóból: $1" ;;
        purge_start)      echo "🗑 Csomag teljes törlése: $1" ;;
        purge_done)       echo "✅ Törlés kész." ;;
        no_package)       echo "❌ Nem található csomag: $1" ;;
        available_pkgs)   echo "📦 Elérhető csomagok:" ;;
        *)                echo "$KEY $*" ;;
      esac
      ;;

    *)
      case "$KEY" in
        build_start)      echo "🔧 Building package: $1" ;;
        package_created)  echo "✅ Package created: $1" ;;
        publish_start)    echo "📤 Publishing package: $1" ;;
        publish_done)     echo "✅ Publish complete." ;;
        remove_start)     echo "🧹 Removing package from repository: $1" ;;
        purge_start)      echo "🗑 Purging package: $1" ;;
        purge_done)       echo "✅ Purge complete." ;;
        no_package)       echo "❌ No package found: $1" ;;
        available_pkgs)   echo "📦 Available packages:" ;;
        *)                echo "$KEY $*" ;;
      esac
      ;;
  esac
}
