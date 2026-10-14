# Display backend

A 1×1-point click-through Metal surface renders extended-linear content through a CAMetalLayer. A separate CoreGraphics gamma adjustment scales the desktop from an immutable captured baseline. A transparent EDR window alone does not brighten other applications.

The backend is gated to built-in, non-mirrored displays with potential EDR headroom. Requested output is limited by the saved maximum and current relative headroom. A dynamically loaded DisplayServices adapter controls only ordinary 0–1 hardware brightness. This private API can change with macOS versions; a capability check must pass before physical-key interception starts. No direct-XDR backend is claimed.

The tested macOS 27 getter returns a clipped table representation. The implementation accepts either the exact requested table or its complete SDR-clipped representation, rejecting other results. Restoration verifies the captured baseline. This validates a transaction, not luminance or absence of HDR clipping.

Already boosted baselines and detectable clipped plateaus are refused. Subsequent changes from another gamma controller relinquish ownership rather than overwrite that controller. Temporary restore failures retain the baseline for retry. There is no global gamma reset or continuous forced override of another utility.

The brightness-only event tap runs on a dedicated run loop and queues display work to the main thread. Other keys pass through. Local diagnostics store in-memory brightness counters and a count of system-defined events; they do not store ordinary key text or transmit data.

Recovery hooks restore owned gamma on reset, pause, quit, sleep, display sleep, lock, inactive sessions, topology changes, permission loss, serious/critical thermal conditions, signals and detected backend failures. Wake/unlock only rearm key handling after all suspension reasons clear. Previous extended output never resumes automatically. Normal hardware brightness changes requested by the user are not undone on quit. Abrupt termination cannot guarantee restoration.

See [verification](VERIFICATION.md) for tested versus pending paths, and [attribution](../ATTRIBUTION.md) for technique references and licenses.
