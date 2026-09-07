package sh.paseo.backgroundcall

import android.Manifest
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import expo.modules.kotlin.functions.Queues
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

private const val CALL_ACTION_EVENT_NAME = "onBackgroundCallAction"
private const val AUDIO_ROUTE_EVENT_NAME = "onBackgroundCallAudioRouteChanged"

class PaseoBackgroundCallModule : Module() {
    override fun definition() = ModuleDefinition {
        Name("PaseoBackgroundCall")

        Events(CALL_ACTION_EVENT_NAME, AUDIO_ROUTE_EVENT_NAME)

        OnCreate {
            val context = applicationContext()
            ForegroundActivityTracker.register(context as Application)
            BackgroundCallLifetime.actionListener = { action ->
                sendEvent(CALL_ACTION_EVENT_NAME, mapOf("action" to action))
            }
            CallAudioRouter.stateListener = { state ->
                sendEvent(AUDIO_ROUTE_EVENT_NAME, state.toMap())
            }
        }

        AsyncFunction("begin") {
            val reactActivityIsResumed =
                (appContext.currentActivity as? LifecycleOwner)
                    ?.lifecycle
                    ?.currentState
                    ?.isAtLeast(Lifecycle.State.RESUMED) == true
            check(reactActivityIsResumed || ForegroundActivityTracker.hasResumedActivity()) {
                "A Live Voice background call must begin while Paseo is visible"
            }

            val context = applicationContext()
            val hasMicrophonePermission =
                context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                    PackageManager.PERMISSION_GRANTED
            check(hasMicrophonePermission) {
                "Microphone permission is required before a Live Voice background call begins"
            }
            BackgroundCallLifetime.begin(context)
        }.runOnQueue(Queues.MAIN)

        AsyncFunction("getAudioRoutes") {
            CallAudioRouter.snapshot(applicationContext()).toMap()
        }.runOnQueue(Queues.MAIN)

        AsyncFunction("setAudioRoute") { routeId: String ->
            CallAudioRouter.select(applicationContext(), routeId)
        }.runOnQueue(Queues.MAIN)

        AsyncFunction("setWearNodeNames") { names: List<String> ->
            CallAudioRouter.updateWearNodeNames(names, applicationContext())
        }.runOnQueue(Queues.MAIN)

        AsyncFunction("update") { isMuted: Boolean ->
            appContext.reactContext?.applicationContext?.let { context ->
                BackgroundCallLifetime.update(context, isMuted)
            }
        }.runOnQueue(Queues.MAIN)

        AsyncFunction("end") {
            appContext.reactContext?.applicationContext?.let(BackgroundCallLifetime::end)
        }.runOnQueue(Queues.MAIN)

        OnDestroy {
            BackgroundCallLifetime.actionListener = null
            CallAudioRouter.stateListener = null
            appContext.reactContext?.applicationContext?.let(BackgroundCallLifetime::end)
        }
    }

    private fun applicationContext(): Context {
        return requireNotNull(appContext.reactContext?.applicationContext) {
            "Paseo background-call support requires an active React context"
        }
    }
}

private fun AudioRouteOption.toMap(): Map<String, String> =
    mapOf("id" to id, "label" to label, "kind" to kind.wireValue)

private fun AudioRouteState.toMap(): Map<String, Any?> =
    mapOf("active" to active?.toMap(), "candidates" to candidates.map(AudioRouteOption::toMap))
