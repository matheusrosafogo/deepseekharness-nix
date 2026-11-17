{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchPnpmDeps,
  pnpm_11,
  pnpmConfigHook,
  nodejs_24,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  autoPatchelfHook,
  unzip,
  wrapGAppsHook3,
  gcc,
  gnumake,
  python3,
  git,
  pkg-config,
  # Runtime libraries for Electron/Chromium.
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gst_all_1,
  gtk3,
  harfbuzz,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  libsm,
  libice,
  libpciaccess,
  mesa,
  nspr,
  nss,
  pango,
  systemdLibs,
  vulkan-loader,
  wayland,
  xkeyboard_config,
  xdg-utils,
  zlib,
}:

let
  pname = "deepseek-harness";
  version = "0.2.2-rc.3";
  electronVersion = "44.7.0";

  primaryRuntimeAssets = import ./primary-runtime-assets.nix { inherit fetchurl; };
  primaryRuntimeAssetsJson = builtins.toJSON (map (asset: {
    inherit (asset) sha256;
    path = "${asset.src}";
  }) primaryRuntimeAssets);

  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    # libstdc++ is required by the prebuilt native addons.
    stdenv.cc.cc.lib
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gtk3
    harfbuzz
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    libsm
    libice
    libpciaccess
    mesa
    nspr
    nss
    pango
    systemdLibs
    vulkan-loader
    wayland
    xkeyboard_config
    zlib
  ];

  desktopItem = makeDesktopItem {
    name = "deepseek-harness";
    desktopName = "DeepSeek Harness";
    exec = "deepseek-harness %U";
    icon = "deepseek-harness";
    comment = "Agent harness developed by DeepSeek AI";
    categories = [ "Development" ];
    terminal = false;
    startupWMClass = "DeepSeek Harness";
  };

  # The native require-builtin addon checks the exact Electron runtime
  # fingerprint. nixpkgs' electron_44 has moved past 44.7.0, so use the
  # matching official Electron distribution instead.
  electron = stdenv.mkDerivation {
    pname = "electron";
    version = electronVersion;

    src = fetchurl {
      url = "https://github.com/electron/electron/releases/download/v${electronVersion}/electron-v${electronVersion}-linux-x64.zip";
      hash = "sha256-OufVva1hxmRIbGq2E2HdCE0GTIwIr40TpocJbhjOVVo=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      unzip
      wrapGAppsHook3
    ];

    buildInputs = runtimeLibs;

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;
    dontWrapGApps = true;

    unpackPhase = ''
      runHook preUnpack
      unzip -q "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/electron $out/bin
      cp -a . $out/lib/electron/
      runHook postInstall
    '';

    postFixup = ''
      autoPatchelf --no-recurse $out/lib/electron
      makeWrapper $out/lib/electron/electron $out/bin/electron \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
        --set CHROME_DEVEL_SANDBOX $out/lib/electron/chrome-sandbox
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    tag = "dsh-v${version}";
    hash = "sha256-0stwYEjQsZ3dfQbIhEN8kR1B/WxsnWDMZ84HIBDbnKg=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 5;
    hash = "sha256-8GQ1IYvDx7FTlZCgYRZHomjDMZ8kJCK4BqIy1QAiG8Y=";
  };

  nativeBuildInputs = [
    nodejs_24
    pnpm_11
    pnpmConfigHook
    makeWrapper
    copyDesktopItems
    gcc
    gnumake
    python3
    git
    pkg-config
  ];

  env = {
    CI = "true";
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    # The source archive is not a Git checkout; embed the tag commit instead.
    DSH_CLIENT_COMMIT_HASH = "38a6a5c965aa99ab525161efb7cc5cf1fe62fced";
  };

  patches = [ ./patches/linux-desktop.patch ];

  # pnpmConfigHook installs with --ignore-scripts so no lifecycle script can
  # reach the network. node-pty's prebuilt helper only needs its executable bit.
  preBuild = ''
    node packages/subprocess/subprocess-local/scripts/ensure-spawn-helper.mjs
  '';

  buildPhase = ''
    runHook preBuild
    pnpm run build:artifacts
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    appRoot=$out/share/deepseek-harness
    mkdir -p $appRoot
    cp -a . $appRoot/
    install -Dm644 ${./nix/prepare-desktop-project.mjs} $appRoot/nix/prepare-desktop-project.mjs
    install -Dm644 ${./nix/prepare-primary-runtime.mjs} $appRoot/nix/prepare-primary-runtime.mjs

    node --import tsx/esm $appRoot/nix/prepare-desktop-project.mjs

    install -Dm644 apps/desktop/resources/icon.png \
      $out/share/icons/hicolor/1024x1024/apps/deepseek-harness.png

    runHook postInstall
  '';

  postFixup = ''
    appRoot=$out/share/deepseek-harness
    assetsFile=$(mktemp)
    cat > "$assetsFile" <<'EOF'
${primaryRuntimeAssetsJson}
EOF

    # Generate after the generic fixup so patchShebangs/strip do not rewrite
    # the self-contained Python payload.
    export PRIMARY_RUNTIME_ASSETS="$assetsFile"
    export PRIMARY_RUNTIME_CACHE="$(mktemp -d)"
    # The sandbox has no /lib64 loader for the payload's native interpreters;
    # upstream smoke checks are run by the development flow on a real host.
    export PRIMARY_RUNTIME_SMOKE=0
    cd "$appRoot"
    node --import tsx/esm "$appRoot/nix/prepare-primary-runtime.mjs"

    makeWrapper ${electron}/bin/electron $out/bin/deepseek-harness \
      --add-flags "$out/share/deepseek-harness/apps/desktop" \
      --set DSH_DESKTOP_PRIMARY_RUNTIME_DIR "$out/share/deepseek-harness/primary-runtime" \
      --set DSH_DESKTOP_DSH_DIR "$out/share/deepseek-harness/apps/desktop/.desktop-build/development/project" \
      --set DSH_DESKTOP_PNPM_ENTRY "$out/share/deepseek-harness/apps/desktop/node_modules/pnpm/bin/pnpm.mjs" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"
  '';

  desktopItems = [ desktopItem ];

  meta = {
    description = "Agent harness developed by DeepSeek AI";
    homepage = "https://deepseek-harness.github.io/deepseek-harness/";
    downloadPage = "https://github.com/deepseek-ai/deepseek-harness/releases";
    license = lib.licenses.mit;
    mainProgram = "deepseek-harness";
    platforms = [ "x86_64-linux" ];
  };
})
