package dev.dimension.flare.ui.model

import kotlin.test.Test
import kotlin.test.assertEquals

class UiHandleTest {
    @Test
    fun displayDropsAHostTheHandleAlreadyCarries() {
        // Mastodon: the instance is not part of the username, so it is shown.
        assertEquals("@user@mastodon.social", UiHandle("user", "mastodon.social").display)
        // Bluesky: the handle is already a full domain.
        assertEquals("@name.bsky.social", UiHandle("name.bsky.social", "bsky.social", showsHost = false).display)
        assertEquals("@example.com", UiHandle("example.com", "bsky.social", showsHost = false).display)
        // Handles cached before showsHost existed still lose a duplicated host.
        assertEquals("@name.bsky.social", UiHandle("name.bsky.social", "bsky.social").display)
        // The stable key is unchanged.
        assertEquals("@name.bsky.social@bsky.social", UiHandle("name.bsky.social", "bsky.social", showsHost = false).canonical)
    }
}
