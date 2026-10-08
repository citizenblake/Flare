package dev.dimension.flare.ui.model

import androidx.compose.runtime.Immutable
import kotlinx.serialization.Serializable

@Serializable
@Immutable
public data class UiHandle(
    val raw: String,
    val host: String,
    // False where the handle is already a full domain (Bluesky), so the host adds nothing.
    val showsHost: Boolean = true,
) {
    val normalizedRaw: String
        get() = raw.trim().removePrefix("@").substringBefore("@")

    val normalizedHost: String
        get() = host.trim().removePrefix("@")

    val canonical: String
        get() = "@$normalizedRaw@$normalizedHost"

    /**
     * The handle as shown to people. [canonical] stays the stable key; it always appends the
     * host, which reads as `@name.bsky.social@bsky.social` for Bluesky. The suffix check
     * also covers handles cached before [showsHost] existed.
     */
    val display: String
        get() =
            if (!showsHost || normalizedRaw == normalizedHost || normalizedRaw.endsWith(".$normalizedHost")) {
                "@$normalizedRaw"
            } else {
                canonical
            }
}
