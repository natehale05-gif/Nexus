#!/usr/bin/env bash
# Builds a NEXUS .deb from a `flutter build linux --release` bundle.
#
#   packaging/linux/build-deb.sh <bundle-dir> <version> <output.deb>
#
# Produces a package that actually installs: the app lands in /opt/nexus, gets
# a /usr/bin/nexus launcher on PATH, and registers a .desktop entry + icon so
# it shows up in the applications menu like any other app. apt pulls the GTK /
# mpv / libsecret runtime libraries via Depends, so users don't have to read a
# README to find out why it won't start.
set -euo pipefail

bundle="${1:?usage: build-deb.sh <bundle-dir> <version> <output.deb>}"
version="${2:?missing version}"
output="${3:?missing output path}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"

[ -d "$bundle" ] || { echo "bundle dir not found: $bundle" >&2; exit 1; }
[ -x "$bundle/nexus" ] || { echo "no 'nexus' executable in $bundle" >&2; exit 1; }

# Debian versions must start with a digit, so a tag like v0.2.0 becomes 0.2.0.
version="${version#v}"
case "$version" in
  [0-9]*) ;;
  *) echo "version must start with a digit (got '$version')" >&2; exit 1 ;;
esac

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
# mktemp -d gives 0700; that mode ends up on the package's root directory entry
# and dpkg would apply it on install.
chmod 755 "$staging"

install -d "$staging/opt/nexus"
cp -a "$bundle/." "$staging/opt/nexus/"

install -d "$staging/usr/bin"
ln -s /opt/nexus/nexus "$staging/usr/bin/nexus"

install -d "$staging/usr/share/applications"
install -m 644 "$here/nexus.desktop" "$staging/usr/share/applications/nexus.desktop"

install -d "$staging/usr/share/icons/hicolor/512x512/apps"
install -m 644 "$repo_root/app/web/icons/Icon-512.png" \
  "$staging/usr/share/icons/hicolor/512x512/apps/nexus.png"
install -d "$staging/usr/share/icons/hicolor/192x192/apps"
install -m 644 "$repo_root/app/web/icons/Icon-192.png" \
  "$staging/usr/share/icons/hicolor/192x192/apps/nexus.png"

# Work out the runtime library dependencies from the actual ELF binaries rather
# than hardcoding package names that drift between Ubuntu releases (libmpv1 vs
# libmpv2, libjsoncpp1 vs libjsoncpp25, ...). Falls back to a hand-written list
# if dpkg-shlibdeps isn't available or can't resolve everything.
#
# The computed list *augments* rather than replaces the known-required set:
# shlibdeps only sees what the ELF headers declare, so anything loaded
# indirectly would silently drop out and the app would fail to start on a
# clean machine with no hint why.
essential_depends="libgtk-3-0 (>= 3.24), libmpv2 | libmpv1, libsecret-1-0, libepoxy0"
depends="$essential_depends"
if command -v dpkg-shlibdeps >/dev/null 2>&1; then
  shlibdir="$(mktemp -d)"
  mkdir -p "$shlibdir/debian"
  # dpkg-shlibdeps insists on a source package context even with -O.
  printf 'Source: nexus\n\nPackage: nexus\nArchitecture: amd64\n' \
    > "$shlibdir/debian/control"
  : > "$shlibdir/debian/nexus.substvars"
  mapfile -t elves < <(
    printf '%s\n' "$staging/opt/nexus/nexus"
    find "$staging/opt/nexus/lib" -name '*.so*' -type f 2>/dev/null || true
  )
  if computed="$(cd "$shlibdir" && dpkg-shlibdeps -O --ignore-missing-info \
        "${elves[@]}" 2>/dev/null)"; then
    computed="${computed#shlibs:Depends=}"
    if [ -n "$computed" ]; then
      depends="$computed"
      # Add back any essential clause whose package shlibdeps didn't mention.
      while IFS= read -r clause; do
        [ -n "$clause" ] || continue
        pkg="${clause%% *}"; pkg="${pkg%% |*}"
        case ",$depends," in
          *"$pkg"*) ;;
          *) depends="$depends, $clause" ;;
        esac
      done < <(printf '%s\n' "$essential_depends" | tr ',' '\n' | sed 's/^ *//; s/ *$//')
    fi
  else
    echo "note: dpkg-shlibdeps failed; using the hand-written Depends list" >&2
  fi
  rm -rf "$shlibdir"
fi

installed_kb="$(du -ks "$staging" | cut -f1)"

install -d "$staging/DEBIAN"
cat > "$staging/DEBIAN/control" <<EOF
Package: nexus
Version: $version
Section: utils
Priority: optional
Architecture: amd64
Depends: $depends
Installed-Size: $installed_kb
Maintainer: NEXUS <noreply@github.com>
Homepage: https://github.com/natehale05-gif/Nexus
Description: Control surface for the NEXUS compound
 NEXUS is a map-first desktop app for running a compound: per-building room
 and device control, security camera views, a media library with offline
 downloads, and a multi-provider AI assistant.
 .
 Server-backed features (media, cameras, device control) need a paired
 nexus_server; until then the app runs in local demo mode.
EOF

# Refresh the desktop/icon caches so the launcher entry appears without a
# re-login. Both tools are optional - a headless install shouldn't fail here.
cat > "$staging/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database -q /usr/share/applications || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -q -f -t /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 755 "$staging/DEBIAN/postinst"

cat > "$staging/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
  command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database -q /usr/share/applications || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -q -f -t /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 755 "$staging/DEBIAN/postrm"

mkdir -p "$(dirname "$output")"
dpkg-deb --build --root-owner-group "$staging" "$output"
echo "Built $output"
