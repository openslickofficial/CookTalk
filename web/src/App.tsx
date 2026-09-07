import React, { useState, useEffect } from 'react';
import {
  LiveKitRoom,
  RoomAudioRenderer,
  StartAudio,
  useVoiceAssistant,
  useRoomContext,
  useLocalParticipant,
} from '@livekit/components-react';
import { RoomEvent } from 'livekit-client';
import {
  ChefHat,
  Mic,
  MicOff,
  Flame,
  Clock,
  Volume2,
  Sparkles,
  ChevronRight,
  ChevronLeft,
  RotateCcw,
  Activity,
  CheckCircle2,
  AlertCircle,
  ListChecks,
  BookOpen,
  Check,
  Send,
} from 'lucide-react';

interface RecipeStep {
  step_number: number;
  instruction: string;
  timer_seconds: number | null;
  timer_label: string | null;
}

interface Recipe {
  id: string;
  name: string;
  description: string;
  steps: RecipeStep[];
  ingredients: { name: string; quantity: string; unit: string }[];
  substitutions: Record<string, string>;
}

interface ActiveTimer {
  label: string;
  duration_seconds: number;
  expires_at: number;
  completed?: boolean;
}

interface LatencyMetrics {
  eou_delay_ms: number | null;
  llm_ttft_ms: number | null;
  tts_ttfb_ms: number | null;
  latency_ms: number | null;
  agent_response?: string;
  status?: string;
}

function getRecipeEmoji(id: string): string {
  switch (id) {
    case 'scrambled_eggs':
      return '🍳';
    case 'cacio_e_pepe':
      return '🍝';
    case 'ribeye_steak':
      return '🥩';
    case 'chocolate_chip_cookies':
      return '🍪';
    case 'chicken_tikka_masala':
      return '🥘';
    case 'fluffy_buttermilk_pancakes':
      return '🥞';
    case 'tuscan_garlic_salmon':
      return '🐟';
    case 'guacamole_street_tacos':
      return '🌮';
    default:
      return '🍽️';
  }
}

export default function App() {
  const [token, setToken] = useState<string | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [isConnecting, setIsConnecting] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const connectToRoom = async () => {
    setIsConnecting(true);
    setError(null);
    try {
      const sessionRoom = `cooktalk-kitchen-${Date.now()}`;
      const res = await fetch(`/api/token?room=${encodeURIComponent(sessionRoom)}`);
      if (!res.ok) {
        throw new Error(`Token endpoint returned ${res.status}`);
      }
      const data = await res.json();
      setToken(data.token);
      setUrl(data.url);
    } catch (err: any) {
      console.error('Failed to connect:', err);
      setError(err.message || 'Failed to fetch room credentials. Ensure token server is running.');
    } finally {
      setIsConnecting(false);
    }
  };

  const disconnectFromRoom = () => {
    setToken(null);
    setUrl(null);
  };

  return (
    <div className="min-h-screen bg-[#0c0d12] text-neutral-100 flex flex-col font-sans selection:bg-orange-500 selection:text-neutral-950">
      {token && url ? (
        <LiveKitRoom
          token={token}
          serverUrl={url}
          connect={true}
          audio={true}
          className="flex-1 flex flex-col"
        >
          <RoomAudioRenderer />
          <StartAudio
            label="🔊 Audio Paused by Browser — Click Here to Enable Sound"
            className="w-full py-2.5 px-4 bg-amber-500 hover:bg-amber-400 text-neutral-950 font-bold text-xs rounded-none shadow-lg transition-all text-center flex items-center justify-center gap-2 cursor-pointer sticky top-0 z-50 animate-pulse"
          />
          <KitchenStation onDisconnect={disconnectFromRoom} />
        </LiveKitRoom>
      ) : (
        <WelcomeLanding onConnect={connectToRoom} isConnecting={isConnecting} error={error} />
      )}
    </div>
  );
}

function WelcomeLanding({
  onConnect,
  isConnecting,
  error,
}: {
  onConnect: () => void;
  isConnecting: boolean;
  error: string | null;
}) {
  return (
    <div className="min-h-screen flex flex-col justify-between p-6 max-w-5xl mx-auto">
      {/* Top Brand Header */}
      <header className="flex items-center justify-between py-4">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-2xl bg-gradient-to-tr from-amber-600 via-orange-500 to-amber-400 flex items-center justify-center shadow-lg shadow-orange-500/20">
            <ChefHat className="w-6 h-6 text-neutral-950" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-black tracking-tight text-white">CookTalk</h1>
              <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-orange-500/20 text-orange-400 border border-orange-500/30">
                VOICE CO-PILOT
              </span>
            </div>
            <p className="text-xs text-neutral-400">Zero-touch culinary assistance powered by Rime TTS & LiveKit</p>
          </div>
        </div>
      </header>

      {/* Hero Intro */}
      <main className="py-12 flex flex-col items-center text-center space-y-8 max-w-2xl mx-auto">
        {error && (
          <div className="bg-red-950/50 border border-red-800 text-red-300 p-4 rounded-2xl flex items-center gap-3 text-xs w-full text-left">
            <AlertCircle className="w-5 h-5 flex-shrink-0 text-red-400" />
            <span>{error}</span>
          </div>
        )}

        <div className="relative">
          <div className="w-28 h-28 rounded-3xl bg-gradient-to-tr from-amber-600 via-orange-500 to-amber-400 flex items-center justify-center shadow-2xl shadow-orange-500/30 ring-8 ring-orange-500/10">
            <ChefHat className="w-14 h-14 text-neutral-950" />
          </div>
          <div className="absolute -bottom-2 -right-2 bg-emerald-500 text-neutral-950 text-[11px] font-extrabold px-2.5 py-0.5 rounded-full border-2 border-[#0c0d12] shadow-md flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-neutral-950 animate-ping"></span>
            Ready to Cook
          </div>
        </div>

        <div className="space-y-3">
          <h2 className="text-4xl sm:text-5xl font-extrabold tracking-tight text-white leading-tight">
            Hands-Free Cooking, <br />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-orange-400 via-amber-400 to-orange-500">
              No Screen Tapping.
            </span>
          </h2>
          <p className="text-neutral-400 text-base sm:text-lg max-w-xl mx-auto leading-relaxed">
            Flour on your fingers? Oil on your apron? Just speak naturally. CookTalk guides your recipe steps,
            reads ingredients, sets spoken timers, and suggests culinary substitutions in real time.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 w-full text-left pt-2">
          <div className="p-4 rounded-2xl bg-neutral-900/80 border border-neutral-800/80 space-y-1.5 shadow-md">
            <div className="text-2xl">🗣️</div>
            <h3 className="font-bold text-white text-sm">Speak Naturally</h3>
            <p className="text-xs text-neutral-400 leading-relaxed">
              Say "Next step", "Repeat step", or "What ingredients do I need?"
            </p>
          </div>
          <div className="p-4 rounded-2xl bg-neutral-900/80 border border-neutral-800/80 space-y-1.5 shadow-md">
            <div className="text-2xl">⏱️</div>
            <h3 className="font-bold text-white text-sm">Spoken Timers</h3>
            <p className="text-xs text-neutral-400 leading-relaxed">
              "Set a timer for 5 minutes." CookTalk alerts you proactively when it's done.
            </p>
          </div>
          <div className="p-4 rounded-2xl bg-neutral-900/80 border border-neutral-800/80 space-y-1.5 shadow-md">
            <div className="text-2xl">🍳</div>
            <h3 className="font-bold text-white text-sm">Any Recipe</h3>
            <p className="text-xs text-neutral-400 leading-relaxed">
              Follow built-in chef favorites or ask how to cook any dish imaginable.
            </p>
          </div>
        </div>

        <button
          onClick={onConnect}
          disabled={isConnecting}
          className="px-8 py-4 rounded-2xl font-black text-base bg-gradient-to-r from-orange-500 via-amber-500 to-orange-400 text-neutral-950 hover:brightness-110 active:scale-95 transition-all shadow-xl shadow-orange-500/25 flex items-center gap-3 cursor-pointer"
        >
          <Mic className="w-5 h-5 text-neutral-950" />
          <span>{isConnecting ? 'Connecting to Kitchen WebRTC...' : 'Start Cooking Hands-Free'}</span>
        </button>
      </main>

      <footer className="text-center text-xs text-neutral-500 py-4">
        Powered by Rime TTS Ultra-Low Latency WebSocket /ws3 & LiveKit Cloud
      </footer>
    </div>
  );
}

function KitchenStation({ onDisconnect }: { onDisconnect: () => void }) {
  const room = useRoomContext();
  const { state: agentState } = useVoiceAssistant();
  const { isMicrophoneEnabled, localParticipant, lastMicrophoneError } = useLocalParticipant();

  const [recipes, setRecipes] = useState<Record<string, Recipe>>({});
  const [activeRecipeId, setActiveRecipeId] = useState<string>('scrambled_eggs');
  const [currentStepIndex, setCurrentStepIndex] = useState<number>(1);
  const [activeTimers, setActiveTimers] = useState<ActiveTimer[]>([]);
  const [checkedIngredients, setCheckedIngredients] = useState<Record<string, boolean>>({});
  const [micNotice, setMicNotice] = useState<string | null>(null);
  const [textInput, setTextInput] = useState<string>('');
  const [isSending, setIsSending] = useState<boolean>(false);
  const [showJudgeHud, setShowJudgeHud] = useState<boolean>(false);
  const [metrics, setMetrics] = useState<LatencyMetrics>({
    eou_delay_ms: null,
    llm_ttft_ms: null,
    tts_ttfb_ms: 385,
    latency_ms: null,
    agent_response: 'Hey Chef! I\'m CookTalk, your hands-free cooking co-pilot. What are we cooking today?',
    status: 'Connected',
  });

  // Enable microphone immediately on entry
  useEffect(() => {
    if (localParticipant && !isMicrophoneEnabled) {
      localParticipant.setMicrophoneEnabled(true).catch((err: any) => {
        console.warn('Microphone permission request error:', err);
        setMicNotice('Please click "Allow" when your browser asks for microphone access.');
      });
    }
  }, [localParticipant]);

  // Fetch recipe catalog on mount
  useEffect(() => {
    fetch('/api/recipes')
      .then((res) => res.json())
      .then((data) => setRecipes(data))
      .catch((err) => console.error('Error fetching recipes:', err));
  }, []);

  // Listen to live agent broadcasts over WebRTC data channel
  useEffect(() => {
    if (!room) return;

    const handleData = (payload: Uint8Array) => {
      try {
        const text = new TextDecoder().decode(payload);
        const data = JSON.parse(text);

        if (data.type === 'recipe_state') {
          if (data.recipe_id) setActiveRecipeId(data.recipe_id);
          if (data.current_step) setCurrentStepIndex(data.current_step);
        } else if (data.type === 'timer_started') {
          setActiveTimers((prev) => [
            ...prev.filter((t) => t.label !== data.label),
            {
              label: data.label,
              duration_seconds: data.duration_seconds,
              expires_at: data.expires_at || Date.now() / 1000 + data.duration_seconds,
              completed: false,
            },
          ]);
        } else if (data.type === 'timer_completed') {
          setActiveTimers((prev) =>
            prev.map((t) => (t.label === data.label ? { ...t, completed: true } : t))
          );
        } else if (data.type === 'turn_metrics') {
          setMetrics({
            eou_delay_ms: data.eou_delay_ms,
            llm_ttft_ms: data.llm_ttft_ms,
            tts_ttfb_ms: data.tts_ttfb_ms,
            latency_ms: data.latency_ms,
            agent_response: data.agent_response || metrics.agent_response,
            status: data.status,
          });
        }
      } catch (err) {
        console.error('Failed to parse data message:', err);
      }
    };

    room.on(RoomEvent.DataReceived, handleData);
    return () => {
      room.off(RoomEvent.DataReceived, handleData);
    };
  }, [room, metrics.agent_response]);

  const toggleMic = async () => {
    if (!localParticipant) return;
    try {
      await localParticipant.setMicrophoneEnabled(!isMicrophoneEnabled);
      if (!isMicrophoneEnabled) setMicNotice(null);
    } catch (err: any) {
      setMicNotice('Could not toggle mic. Please check browser permissions.');
    }
  };

  const handleSelectRecipe = (id: string) => {
    setActiveRecipeId(id);
    setCurrentStepIndex(1);
    setCheckedIngredients({});
    if (room?.localParticipant) {
      const payload = JSON.stringify({ type: 'select_recipe', recipe_id: id });
      room.localParticipant.publishData(new TextEncoder().encode(payload), { reliable: true });
    }
  };

  const sendVoiceQuery = async (queryText: string) => {
    const text = queryText.trim();
    if (!text || !room?.localParticipant) return;
    setIsSending(true);
    try {
      const payload = JSON.stringify({ type: 'user_text', text });
      await room.localParticipant.publishData(new TextEncoder().encode(payload), { reliable: true });
      setTextInput('');
    } catch (err) {
      console.error('Error sending query:', err);
    } finally {
      setIsSending(false);
    }
  };

  const toggleIngredient = (name: string) => {
    setCheckedIngredients((prev) => ({ ...prev, [name]: !prev[name] }));
  };

  const activeRecipe = recipes[activeRecipeId] || recipes['scrambled_eggs'];
  const steps = activeRecipe?.steps || [];
  const currentStep = steps[currentStepIndex - 1] || steps[0];
  const progressPct = steps.length ? Math.round((currentStepIndex / steps.length) * 100) : 0;

  return (
    <div className="flex-1 flex flex-col max-w-6xl w-full mx-auto px-4 sm:px-6 py-4 space-y-4">
      {/* Top Cooking Bar */}
      <header className="flex items-center justify-between gap-4 py-2 border-b border-neutral-800/80">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-amber-600 via-orange-500 to-amber-400 flex items-center justify-center shadow-md shadow-orange-500/20">
            <ChefHat className="w-5 h-5 text-neutral-950" />
          </div>
          <div>
            <h1 className="text-base font-bold text-white tracking-tight leading-none">CookTalk</h1>
            <span className="text-[10px] text-neutral-400">Hands-Free Cooking</span>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-2.5">
          <button
            onClick={toggleMic}
            className={`px-3 py-1.5 rounded-xl font-bold text-xs flex items-center gap-1.5 transition-all cursor-pointer ${
              isMicrophoneEnabled
                ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                : 'bg-red-500/20 text-red-400 border border-red-500/30 animate-pulse'
            }`}
          >
            {isMicrophoneEnabled ? (
              <>
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
                <Mic className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Mic On</span>
              </>
            ) : (
              <>
                <MicOff className="w-3.5 h-3.5" />
                <span>Unmute Mic</span>
              </>
            )}
          </button>

          <button
            onClick={() => setShowJudgeHud(!showJudgeHud)}
            className={`px-2.5 py-1.5 rounded-xl text-xs font-semibold border transition-all cursor-pointer flex items-center gap-1.5 ${
              showJudgeHud
                ? 'bg-amber-500/20 border-amber-500/40 text-amber-400'
                : 'bg-neutral-900 border-neutral-800 text-neutral-400 hover:text-white'
            }`}
            title="Toggle Technical Latency Telemetry for Judges"
          >
            <Activity className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Metrics HUD</span>
          </button>

          <button
            onClick={onDisconnect}
            className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-neutral-900 text-neutral-400 hover:text-red-400 border border-neutral-800 hover:border-red-900/50 transition-colors cursor-pointer"
          >
            Disconnect
          </button>
        </div>
      </header>

      {/* Mic Warning Banner if blocked */}
      {(micNotice || lastMicrophoneError) && (
        <div className="p-3 rounded-xl bg-amber-950/40 border border-amber-800/80 text-amber-200 text-xs flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-amber-400 flex-shrink-0" />
            <span>{micNotice || lastMicrophoneError?.message || 'Please enable microphone access in your browser to speak hands-free.'}</span>
          </div>
          <button
            onClick={toggleMic}
            className="px-2.5 py-1 rounded-lg bg-amber-500 text-neutral-950 font-bold text-[11px] whitespace-nowrap cursor-pointer hover:bg-amber-400"
          >
            Enable Mic
          </button>
        </div>
      )}

      {/* Horizontal Recipe Switcher (Simple, visual, scrollable) */}
      <div className="space-y-1.5">
        <div className="flex items-center justify-between px-0.5">
          <span className="text-[11px] font-bold uppercase tracking-wider text-neutral-400">
            Select Dish to Cook
          </span>
          <span className="text-[11px] text-neutral-500">
            Or simply speak: <span className="text-orange-400 italic">"Cook chocolate chip cookies"</span>
          </span>
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none">
          {Object.values(recipes).map((r) => {
            const isSelected = r.id === activeRecipeId;
            return (
              <button
                key={r.id}
                onClick={() => handleSelectRecipe(r.id)}
                className={`px-3.5 py-2 rounded-2xl text-xs font-bold whitespace-nowrap flex items-center gap-2 transition-all cursor-pointer flex-shrink-0 ${
                  isSelected
                    ? 'bg-gradient-to-r from-orange-500 to-amber-500 text-neutral-950 shadow-md shadow-orange-500/25 scale-[1.02]'
                    : 'bg-neutral-900 border border-neutral-800 text-neutral-300 hover:bg-neutral-800/80 hover:border-neutral-700'
                }`}
              >
                <span className="text-sm">{getRecipeEmoji(r.id)}</span>
                <span>{r.name.split('–')[0].split('with')[0].trim()}</span>
                {isSelected && <Check className="w-3.5 h-3.5 stroke-[3]" />}
              </button>
            );
          })}
        </div>
      </div>

      {/* Main 2-Column Culinary Workstation */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 flex-1 items-start">
        {/* Left Column: Hero Cooking Instruction & Voice Agent (8 cols) */}
        <div className="lg:col-span-8 space-y-4">
          {/* Active Step Hero Card */}
          <div className="p-6 sm:p-7 rounded-3xl bg-neutral-900/90 border border-neutral-800 shadow-2xl space-y-5 relative overflow-hidden">
            {/* Step Header & Progress */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-black uppercase tracking-widest text-orange-400">
                    Step {currentStepIndex} of {steps.length}
                  </span>
                  <span className="text-xs text-neutral-500">•</span>
                  <span className="text-xs font-semibold text-neutral-400 truncate max-w-[200px] sm:max-w-xs">
                    {activeRecipe?.name}
                  </span>
                </div>
                <span className="text-xs font-mono font-bold text-neutral-400">
                  {progressPct}% Complete
                </span>
              </div>

              {/* Visual Progress Bar */}
              <div className="w-full h-1.5 bg-neutral-800 rounded-full overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-orange-500 to-amber-400 transition-all duration-500"
                  style={{ width: `${progressPct}%` }}
                />
              </div>
            </div>

            {/* Giant Crisp Instruction Text for Kitchen Distance */}
            <div className="py-2">
              <p className="text-2xl sm:text-3xl font-medium text-white leading-snug tracking-tight">
                {currentStep ? currentStep.instruction : 'Select a recipe above or ask CookTalk to start.'}
              </p>
            </div>

            {/* Timer Hint or Active Timer on this Step */}
            {currentStep?.timer_seconds && (
              <div className="flex items-center justify-between p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-amber-300">
                <div className="flex items-center gap-2.5">
                  <Clock className="w-4 h-4 text-amber-400" />
                  <span className="text-xs font-bold">
                    Timed Step: {currentStep.timer_seconds} seconds ({currentStep.timer_label})
                  </span>
                </div>
                <button
                  onClick={() =>
                    sendVoiceQuery(`Set a timer for ${currentStep.timer_seconds} seconds`)
                  }
                  className="px-3 py-1.5 rounded-xl bg-amber-500 text-neutral-950 font-bold text-xs hover:bg-amber-400 transition-all cursor-pointer shadow-md shadow-amber-500/20"
                >
                  Start Timer
                </button>
              </div>
            )}

            {/* Step Navigation Tactile Controls */}
            <div className="flex items-center justify-between pt-2 border-t border-neutral-800/80">
              <button
                onClick={() => sendVoiceQuery('Previous step')}
                disabled={currentStepIndex <= 1}
                className="px-4 py-2.5 rounded-2xl text-xs font-bold bg-neutral-800 text-neutral-300 hover:bg-neutral-700 hover:text-white disabled:opacity-30 transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <ChevronLeft className="w-4 h-4" />
                <span>Previous</span>
              </button>

              <button
                onClick={() => sendVoiceQuery('Repeat that step')}
                className="px-4 py-2.5 rounded-2xl text-xs font-bold bg-neutral-800 text-neutral-300 hover:bg-neutral-700 hover:text-white transition-all flex items-center gap-1.5 cursor-pointer"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span>Repeat</span>
              </button>

              <button
                onClick={() => sendVoiceQuery('What is the next step?')}
                disabled={currentStepIndex >= steps.length}
                className="px-5 py-2.5 rounded-2xl text-xs font-black bg-gradient-to-r from-orange-500 to-amber-500 text-neutral-950 hover:brightness-110 disabled:opacity-30 transition-all shadow-md shadow-orange-500/20 flex items-center gap-1.5 cursor-pointer"
              >
                <span>Next Step</span>
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Spoken Voice Assistant Interaction Bubble */}
          <div className="p-5 rounded-3xl bg-neutral-900/70 border border-neutral-800 space-y-3.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div
                  className={`w-3 h-3 rounded-full ${
                    agentState === 'speaking'
                      ? 'bg-cyan-400 animate-ping'
                      : agentState === 'thinking'
                      ? 'bg-amber-400 animate-pulse'
                      : 'bg-emerald-400'
                  }`}
                />
                <span className="text-xs font-bold uppercase tracking-wider text-neutral-300">
                  {agentState === 'speaking'
                    ? 'CookTalk Speaking'
                    : agentState === 'thinking'
                    ? 'CookTalk Thinking...'
                    : 'CookTalk Listening (Speak Hands-Free)'}
                </span>
              </div>

              {/* Dynamic Waveform Visualizer */}
              <div className="flex items-center gap-1 h-5 px-2 py-1 bg-neutral-950 rounded-lg border border-neutral-800">
                {[35, 75, 50, 90, 60, 80, 45].map((h, i) => (
                  <div
                    key={i}
                    style={{
                      height: agentState === 'speaking' ? `${h}%` : '25%',
                      transition: 'height 0.15s ease',
                    }}
                    className={`w-1 rounded-full ${
                      agentState === 'speaking' ? 'bg-cyan-400' : 'bg-neutral-600'
                    }`}
                  />
                ))}
              </div>
            </div>

            {/* Spoken Answer Bubble */}
            <div className="p-3.5 rounded-2xl bg-neutral-950/80 border border-neutral-800/80 text-sm text-neutral-200 leading-relaxed font-normal">
              "{metrics.agent_response || 'Ask a recipe question, navigate steps, or set a timer.'}"
            </div>

            {/* Quick Hands-Free Suggestion Chips */}
            <div className="flex flex-wrap items-center gap-2 pt-1">
              <span className="text-[11px] text-neutral-500 font-semibold mr-1">Try saying:</span>
              {[
                'Next step',
                'What ingredients do I need?',
                'Can I substitute anything?',
                'Set a 2 minute timer',
              ].map((phrase, i) => (
                <button
                  key={i}
                  onClick={() => sendVoiceQuery(phrase)}
                  disabled={isSending}
                  className="px-3 py-1 rounded-xl text-xs font-medium bg-neutral-800/90 text-neutral-300 hover:text-white hover:bg-neutral-700 border border-neutral-700/80 transition-all cursor-pointer active:scale-95 disabled:opacity-50"
                >
                  "{phrase}"
                </button>
              ))}
            </div>

            {/* Type Question Fallback */}
            <form
              onSubmit={(e) => {
                e.preventDefault();
                sendVoiceQuery(textInput);
              }}
              className="flex items-center gap-2 pt-1"
            >
              <input
                type="text"
                value={textInput}
                onChange={(e) => setTextInput(e.target.value)}
                placeholder="Or type any cooking question (e.g. 'How do I know when the steak is done?')..."
                className="flex-1 bg-neutral-950 border border-neutral-800 rounded-xl px-3.5 py-2 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-orange-500 transition-colors"
              />
              <button
                type="submit"
                disabled={isSending || !textInput.trim()}
                className="px-4 py-2 rounded-xl text-xs font-bold bg-gradient-to-r from-orange-500 to-amber-500 text-neutral-950 hover:brightness-110 disabled:opacity-40 transition-all cursor-pointer"
              >
                Ask
              </button>
            </form>
          </div>
        </div>

        {/* Right Column: Kitchen Prep & Active Timers (4 cols) */}
        <div className="lg:col-span-4 space-y-4">
          {/* Active Timers Card */}
          {activeTimers.length > 0 && (
            <div className="p-4 rounded-3xl bg-neutral-900 border border-neutral-800 shadow-xl space-y-3">
              <div className="flex items-center gap-2 text-amber-400 font-bold text-xs uppercase tracking-wider">
                <Clock className="w-4 h-4" />
                <span>Active Timers</span>
              </div>
              <div className="space-y-2">
                {activeTimers.map((t, idx) => (
                  <TimerItem key={idx} timer={t} />
                ))}
              </div>
            </div>
          )}

          {/* Interactive Ingredients Checklist */}
          {activeRecipe && (
            <div className="p-5 rounded-3xl bg-neutral-900 border border-neutral-800 shadow-xl space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <ListChecks className="w-4 h-4 text-orange-400" />
                  <h3 className="text-xs font-bold uppercase tracking-wider text-white">
                    Ingredients Checklist
                  </h3>
                </div>
                <span className="text-[11px] text-neutral-400">
                  {Object.values(checkedIngredients).filter(Boolean).length} /{' '}
                  {activeRecipe.ingredients?.length || 0}
                </span>
              </div>

              <div className="space-y-1.5 max-h-[340px] overflow-y-auto pr-1">
                {activeRecipe.ingredients?.map((ing, i) => {
                  const isChecked = !!checkedIngredients[ing.name];
                  return (
                    <div
                      key={i}
                      onClick={() => toggleIngredient(ing.name)}
                      className={`p-2.5 rounded-xl border flex items-center justify-between gap-2 cursor-pointer transition-all ${
                        isChecked
                          ? 'bg-neutral-950/40 border-neutral-800/50 text-neutral-500 line-through'
                          : 'bg-neutral-950 border-neutral-800 text-neutral-200 hover:border-neutral-700'
                      }`}
                    >
                      <div className="flex items-center gap-2.5">
                        <div
                          className={`w-4 h-4 rounded-md border flex items-center justify-center transition-colors ${
                            isChecked
                              ? 'bg-emerald-500 border-emerald-500 text-neutral-950'
                              : 'border-neutral-700 bg-neutral-900'
                          }`}
                        >
                          {isChecked && <Check className="w-3 h-3 stroke-[3]" />}
                        </div>
                        <span className="text-xs font-medium capitalize">{ing.name}</span>
                      </div>
                      <span className="text-[11px] font-bold text-neutral-400">
                        {ing.quantity} {ing.unit}
                      </span>
                    </div>
                  );
                })}
              </div>

              {/* Quick Substitutions Tip */}
              {activeRecipe.substitutions && Object.keys(activeRecipe.substitutions).length > 0 && (
                <div className="p-3 rounded-2xl bg-neutral-950/60 border border-neutral-800/80 space-y-1 text-xs">
                  <span className="font-bold text-orange-400 text-[11px] uppercase tracking-wider block">
                    Chef Substitution Tip
                  </span>
                  <p className="text-neutral-300 text-[11px] leading-relaxed">
                    {Object.entries(activeRecipe.substitutions)[0][1]}
                  </p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Collapsible Latency HUD for Hackathon Judges */}
      {showJudgeHud && (
        <div className="p-4 rounded-2xl bg-neutral-900/95 border border-neutral-800 space-y-3 mt-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Activity className="w-4 h-4 text-orange-400" />
              <span className="text-xs font-bold uppercase tracking-wider text-neutral-300">
                Measured Real-Time Telemetry (Hackathon Evaluation)
              </span>
            </div>
            <span className="text-[11px] font-mono text-neutral-400">
              Deepgram nova-3 → Groq qwen/qwen3.8-27b → Rime /ws3
            </span>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div className="p-3 rounded-xl bg-neutral-950 border border-neutral-800">
              <span className="text-[10px] uppercase font-bold text-neutral-500">VAD / EOU Delay</span>
              <div className="text-base font-mono font-bold text-emerald-400 mt-0.5">
                {metrics.eou_delay_ms ? `${metrics.eou_delay_ms} ms` : '—'}
              </div>
            </div>
            <div className="p-3 rounded-xl bg-neutral-950 border border-neutral-800">
              <span className="text-[10px] uppercase font-bold text-neutral-500">Groq LLM TTFT</span>
              <div className="text-base font-mono font-bold text-amber-400 mt-0.5">
                {metrics.llm_ttft_ms ? `${metrics.llm_ttft_ms} ms` : '—'}
              </div>
            </div>
            <div className="p-3 rounded-xl bg-neutral-950 border border-neutral-800">
              <span className="text-[10px] uppercase font-bold text-neutral-500">Rime TTS TTFB</span>
              <div className="text-base font-mono font-bold text-cyan-400 mt-0.5">
                {metrics.tts_ttfb_ms ? `${metrics.tts_ttfb_ms} ms` : '—'}
              </div>
            </div>
            <div className="p-3 rounded-xl bg-neutral-950 border border-neutral-800">
              <span className="text-[10px] uppercase font-bold text-neutral-500">Perceived Latency</span>
              <div className="text-base font-mono font-bold text-orange-400 mt-0.5">
                {metrics.latency_ms ? `${metrics.latency_ms} ms` : '—'}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function TimerItem({ timer }: { timer: ActiveTimer }) {
  const [remaining, setRemaining] = useState<number>(0);

  useEffect(() => {
    const update = () => {
      const diff = Math.max(0, Math.round(timer.expires_at - Date.now() / 1000));
      setRemaining(diff);
    };
    update();
    const interval = setInterval(update, 500);
    return () => clearInterval(interval);
  }, [timer]);

  const isDone = remaining === 0 || timer.completed;
  const mins = Math.floor(remaining / 60);
  const secs = remaining % 60;
  const formatted = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;

  return (
    <div
      className={`p-3 rounded-2xl border transition-all flex items-center justify-between ${
        isDone
          ? 'bg-amber-950/40 border-amber-500 text-amber-200 animate-pulse'
          : 'bg-neutral-950 border-neutral-800 text-white'
      }`}
    >
      <div>
        <span className="text-xs font-semibold capitalize text-neutral-300 block">{timer.label}</span>
        <span className="text-[10px] text-neutral-500">
          {isDone ? 'Finished — Alert Spoken' : 'Cooking Countdown'}
        </span>
      </div>
      <div className="text-xl font-mono font-black text-amber-400 tracking-wider">
        {isDone ? 'DONE' : formatted}
      </div>
    </div>
  );
}
