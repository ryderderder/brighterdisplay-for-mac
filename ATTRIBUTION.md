# Attribution and dependencies

BrighterDisplay for Mac source is original and MIT licensed. No third-party binary or package dependencies are incorporated. Public MIT API declarations and technique references informed the implementation; their notices are included under ThirdParty. AppKit, CoreGraphics, Metal, QuartzCore and ApplicationServices are system frameworks. The optional DisplayServices adapter loads the system framework at runtime; it does not distribute it.

BrightIntosh by Niklas R. and contributors (https://github.com/niklasr22/BrightIntosh), licensed GPL-3.0, is acknowledged as a behavioral precedent for XDR desktop brightness and gamma/HDR tradeoffs. Its source was not copied, translated, linked or incorporated. This project's MIT license does not relicense BrightIntosh.

BetterDisplay's public guide (https://betterdisplay.pro/guide/tutorials/xdr-and-hdr-brightness-upscaling/) informed the distinction between software gamma upscaling, experimental direct XDR control and obsolete preset control. No BetterDisplay code, license mechanism, artwork or binary is bundled.

The app uses the system SF Symbol sun.max/sun.max.fill at runtime; no extracted artwork is distributed.


Lunar, copyright (c) 2018 Alin Panaitiu, MIT. Public display API declarations and gamma concepts were reviewed at commit `491ec140bf3f11d55fe5d6e72ae72cc4bcee25cf`. The normal/linear API type signatures in the diagnostic follow those declarations; no encrypted Pro implementation was accessed. License: ThirdParty/Lunar-LICENSE.txt.

XDR Light, copyright (c) 2026 李成喆, MIT, commit `e2ac2b7246815672be2fa4bd20cb88449f203a1b`. Its explicit CAMetalLayer sublayer sizing and 8.0 EDR stimulus informed the corresponding adjustment here. Its global gamma reset and periodic forced gamma reapplication are not used. License: ThirdParty/XDR-Light-LICENSE.txt.

macpow (`k06a/macpow`, MIT, commit `696de22d87acb62fbdd306827fb72ea4a375e537`) was a reference for read-only preset and backlight telemetry in the standalone diagnostic. These OS values are reported as driver telemetry, not physical measurements. License: ThirdParty/macpow-LICENSE.txt.
