package dev.dimension.flare.ui.presenter

import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import dev.dimension.flare.common.PagingState
import dev.dimension.flare.common.isRefreshing
import dev.dimension.flare.data.model.tab.TimelinePresenterFactory
import dev.dimension.flare.data.model.tab.TimelineResolver
import dev.dimension.flare.data.model.tab.UiTimelineTabItem
import dev.dimension.flare.di.koinInject
import dev.dimension.flare.ui.model.UiTimelineV2
import dev.dimension.flare.web.shared.WebPresenter
import kotlinx.coroutines.launch

public class TimelineItemPresenter(
    private val timelineTabItem: UiTimelineTabItem,
    private val isHomeTimeline: Boolean = false,
) : PresenterBase<TimelineItemPresenter.State>() {
    private val timelinePresenterFactory by koinInject<TimelinePresenterFactory>()

    public interface State {
        public val listState: PagingState<UiTimelineV2>

        public fun refreshSync()

        public suspend fun refreshSuspend()

        public suspend fun loadNewerSuspend(refreshIfUncached: Boolean): Int = 0

        public val isRefreshing: Boolean

        public val newerLoadedCount: Int get() = 0
    }

    private val timelinePresenter by lazy {
        timelinePresenterFactory.create(timelineTabItem, isHomeTimeline)
    }

    @Composable
    override fun body(): State {
        val state = timelinePresenter.body()
        val scope = rememberCoroutineScope()
        return object : State {
            override val listState = state.listState
            override val isRefreshing = listState.isRefreshing
            override val newerLoadedCount = state.newerLoadedCount

            override fun refreshSync() {
                scope.launch {
                    state.refresh()
                }
            }

            override suspend fun refreshSuspend() {
                state.refresh()
            }

            override suspend fun loadNewerSuspend(refreshIfUncached: Boolean): Int = state.loadNewer(refreshIfUncached)
        }
    }
}

@WebPresenter("timelineItem")
public class WebTimelineItemPresenter(
    private val loaderKey: String,
) : PresenterBase<TimelineItemPresenter.State>() {
    private val timelineResolver by koinInject<TimelineResolver>()

    private val delegate by lazy {
        TimelineItemPresenter(timelineResolver.toTabItem(loaderKey))
    }

    @Composable
    override fun body(): TimelineItemPresenter.State = delegate.body()
}
