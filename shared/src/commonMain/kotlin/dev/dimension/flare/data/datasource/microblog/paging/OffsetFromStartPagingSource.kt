package dev.dimension.flare.data.datasource.microblog.paging

import androidx.paging.PagingSource.LoadResult
import androidx.paging.PagingState
import dev.dimension.flare.common.BasePagingSource
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Job

internal data class PageInvalidationSubscription(
    val job: Job,
    val ready: Deferred<Unit>? = null,
)

internal sealed interface OffsetFromStartPagingKey {
    data class Append(
        val offset: Int,
    ) : OffsetFromStartPagingKey

    // [anchor] is the item at [anchorPosition] before the refresh. Rows inserted above it
    // move it down; the reload grows by that shift so the item being read stays loaded.
    data class Refresh(
        val limit: Int,
        val anchor: Any? = null,
        val anchorPosition: Int = 0,
    ) : OffsetFromStartPagingKey
}

internal interface OffsetFromStartPageLoader<Item : Any> {
    suspend fun load(
        offset: Int,
        limit: Int,
    ): List<Item>

    /** The item's current offset from the start, or null when it can't be told. */
    suspend fun offsetOf(item: Item): Int? = null

    fun observeInvalidations(invalidate: () -> Unit): PageInvalidationSubscription? = null
}

internal class OffsetFromStartPagingSource<Item : Any>(
    private val loader: OffsetFromStartPageLoader<Item>,
) : BasePagingSource<OffsetFromStartPagingKey, Item>() {
    private var invalidationSubscription: PageInvalidationSubscription? = null

    init {
        invalidationSubscription = loader.observeInvalidations(::invalidate)
        registerInvalidatedCallback {
            invalidationSubscription?.job?.cancel()
            invalidationSubscription = null
        }
    }

    override suspend fun doLoad(params: LoadParams<OffsetFromStartPagingKey>): LoadResult<OffsetFromStartPagingKey, Item> {
        invalidationSubscription?.ready?.await()
        val offset: Int
        val limit: Int
        when (val key = params.key) {
            null -> {
                offset = 0
                limit = params.loadSize
            }

            is OffsetFromStartPagingKey.Append -> {
                offset = key.offset
                limit = params.loadSize
            }

            is OffsetFromStartPagingKey.Refresh -> {
                offset = 0
                @Suppress("UNCHECKED_CAST")
                val anchorOffset = (key.anchor as? Item)?.let { loader.offsetOf(it) }
                val shift = maxOf((anchorOffset ?: key.anchorPosition) - key.anchorPosition, 0)
                limit = maxOf(params.loadSize, key.limit) + shift
            }
        }

        val data = loader.load(offset = offset, limit = limit)
        return LoadResult.Page(
            data = data,
            prevKey = null,
            nextKey =
                data
                    .takeIf { it.size >= limit }
                    ?.let { OffsetFromStartPagingKey.Append(offset + it.size) },
        )
    }

    override fun getRefreshKey(state: PagingState<OffsetFromStartPagingKey, Item>): OffsetFromStartPagingKey? {
        val anchorPosition = state.anchorPosition ?: return null
        val limit =
            maxOf(
                state.config.initialLoadSize,
                anchorPosition + 1 + state.config.pageSize + state.config.prefetchDistance,
            )
        return OffsetFromStartPagingKey.Refresh(
            limit = limit,
            anchor = state.closestItemToPosition(anchorPosition),
            anchorPosition = anchorPosition,
        )
    }
}
