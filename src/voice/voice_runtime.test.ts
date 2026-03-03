import { STTStreamer } from './stt_streamer';
import { TTSEngine } from './tts_engine';
import { VoiceManager } from './voice_manager';

type EmitFn = (payload: {
  event_name: string;
  payload?: Record<string, unknown>;
}) => Promise<void>;

function createEmitterMock() {
  const emit = jest.fn<ReturnType<EmitFn>, Parameters<EmitFn>>(() => Promise.resolve());
  return { emit };
}

describe('Voice runtime', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.clearAllMocks();
  });

  test('STT emits canonical partial and final events', async () => {
    const emitter = createEmitterMock();
    const streamer = new STTStreamer(emitter as never);

    await streamer.startStream();

    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'stt_stream_started',
      payload: {},
    });

    jest.advanceTimersByTime(300);
    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'stt_stream_partial',
      payload: {
        transcript: 'I think the answer is',
        confidence: 0.72,
      },
    });

    jest.advanceTimersByTime(600);
    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'stt_final_transcript',
      payload: {
        transcript: 'I think the answer is photosynthesis.',
        duration_ms: 900,
      },
    });
    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'stt_confidence_scored',
      payload: {
        confidence: 0.91,
      },
    });
  });

  test('STT stop cancels pending partial/final emissions', async () => {
    const emitter = createEmitterMock();
    const streamer = new STTStreamer(emitter as never);

    await streamer.startStream();
    streamer.stopStream();
    jest.runOnlyPendingTimers();

    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'stt_stream_stopped',
      payload: {},
    });
    expect(emitter.emit).not.toHaveBeenCalledWith(
      expect.objectContaining({ event_name: 'stt_stream_partial' }),
    );
    expect(emitter.emit).not.toHaveBeenCalledWith(
      expect.objectContaining({ event_name: 'stt_final_transcript' }),
    );
  });

  test('TTS emits start, first-byte, and completed events', async () => {
    const emitter = createEmitterMock();
    const tts = new TTSEngine(emitter as never);

    const speakPromise = tts.speak('hello learner');

    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'tts_request_started',
      payload: {
        text: 'hello learner',
      },
    });

    jest.advanceTimersByTime(300);
    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'tts_audio_first_byte',
      payload: {
        time_ms: 300,
      },
    });

    jest.advanceTimersByTime(700);
    await speakPromise;

    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'tts_audio_completed',
      payload: {
        duration_ms: 1000,
      },
    });
  });

  test('VoiceManager barge-in emits canonical event and returns to listening', async () => {
    const emitter = createEmitterMock();
    const manager = new VoiceManager(emitter as never, '4-6');

    const speakPromise = manager.speak('explanation');
    jest.advanceTimersByTime(200);

    manager.bargeIn();
    await Promise.resolve();

    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'barge_in_detected',
      payload: {},
    });
    expect(emitter.emit).toHaveBeenCalledWith({
      event_name: 'stt_stream_started',
      payload: {},
    });

    jest.runOnlyPendingTimers();
    await speakPromise;
  });
});
