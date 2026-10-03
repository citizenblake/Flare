package dev.dimension.flare.data.sync

import dev.dimension.flare.common.decodeProtobuf
import dev.dimension.flare.common.encodeProtobuf
import dev.dimension.flare.data.datastore.model.AppSettings
import dev.dimension.flare.data.model.appearance.AppearanceBag
import dev.dimension.flare.data.repository.SettingsRepository
import dev.dimension.flare.di.koinInject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import platform.Foundation.NSNotificationCenter
import platform.Foundation.NSUbiquitousKeyValueStore
import platform.Foundation.NSUbiquitousKeyValueStoreDidChangeExternallyNotification
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

/**
 * Mirrors app settings and appearance through iCloud key-value storage so the user's
 * devices match. The last write wins. AI provider keys and the app version stay local,
 * and home tabs are not synced: a device missing an account deletes that account's tabs.
 */
@OptIn(ExperimentalEncodingApi::class)
public object ICloudSettingsSync {
    private const val APP_SETTINGS = "settings.app"
    private const val APPEARANCE = "settings.appearance"

    private val settingsRepository: SettingsRepository by koinInject()
    private val store get() = NSUbiquitousKeyValueStore.defaultStore
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val json =
        Json {
            encodeDefaults = true
            ignoreUnknownKeys = true
        }

    // Last value written to or read from iCloud per key; a local change equal to it is an echo.
    private val synced = mutableMapOf<String, String>()
    private val lock = Mutex()
    private var started = false

    public fun start() {
        if (started) return
        started = true
        NSNotificationCenter.defaultCenter.addObserverForName(
            name = NSUbiquitousKeyValueStoreDidChangeExternallyNotification,
            `object` = store,
            queue = null,
        ) { _ -> scope.launch { pull() } }
        store.synchronize()
        scope.launch {
            // Adopt the other devices' settings before publishing this one's.
            pull()
            launch { settingsRepository.appSettings.collect { push(APP_SETTINGS, encode(it)) } }
            launch { settingsRepository.appearanceBag.collect { push(APPEARANCE, Base64.encode(it.encodeProtobuf())) } }
        }
    }

    private fun encode(settings: AppSettings): String =
        json.encodeToString(AppSettings.serializer(), settings.copy(version = "", aiConfig = AppSettings.AiConfig()))

    private suspend fun push(
        key: String,
        value: String,
    ) {
        lock.withLock {
            if (synced[key] == value) return
            synced[key] = value
        }
        store.setString(value, key)
    }

    // A value this build can't decode (e.g. from a newer build) is skipped, never applied.
    private suspend fun pull() {
        remoteChange(APP_SETTINGS)?.let { remote ->
            runCatching { json.decodeFromString(AppSettings.serializer(), remote) }.getOrNull()?.let { settings ->
                settingsRepository.updateAppSettings { settings.copy(version = version, aiConfig = aiConfig) }
            }
        }
        remoteChange(APPEARANCE)?.let { remote ->
            runCatching { Base64.decode(remote).decodeProtobuf<AppearanceBag>() }.getOrNull()?.let {
                settingsRepository.replaceAppearance(it)
            }
        }
    }

    private suspend fun remoteChange(key: String): String? {
        val remote = store.stringForKey(key) ?: return null
        return lock.withLock {
            if (synced[key] == remote) return null
            synced[key] = remote
            remote
        }
    }
}
