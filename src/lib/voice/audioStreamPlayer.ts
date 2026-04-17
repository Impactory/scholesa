type StreamState = 'idle' | 'connecting' | 'buffering' | 'playing' | 'done' | 'error';
type StateChangeHandler = (state: StreamState) => void;

export class AudioStreamPlayer {
  private audioContext: AudioContext | null = null;
  private state: StreamState = 'idle';
  private onStateChange: StateChangeHandler | null = null;
  private abortController: AbortController | null = null;
  private scheduledBuffers: AudioBufferSourceNode[] = [];
  private nextStartTime = 0;

  constructor(onStateChange?: StateChangeHandler) {
    this.onStateChange = onStateChange ?? null;
  }

  private setState(state: StreamState) {
    this.state = state;
    this.onStateChange?.(state);
  }

  getState(): StreamState {
    return this.state;
  }

  async play(url: string, init?: RequestInit): Promise<void> {
    this.stop();
    this.setState('connecting');
    this.abortController = new AbortController();

    try {
      this.audioContext = new AudioContext({ sampleRate: 16000 });
      const response = await fetch(url, {
        ...init,
        signal: this.abortController.signal,
      });

      if (!response.ok || !response.body) {
        this.setState('error');
        return;
      }

      this.setState('buffering');
      const reader = response.body.getReader();
      const chunks: Uint8Array[] = [];
      let totalLength = 0;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
        totalLength += value.length;

        if (totalLength >= 4096 && this.state === 'buffering') {
          this.setState('playing');
        }
      }

      const combined = new Uint8Array(totalLength);
      let offset = 0;
      for (const chunk of chunks) {
        combined.set(chunk, offset);
        offset += chunk.length;
      }

      const audioBuffer = await this.audioContext.decodeAudioData(combined.buffer);
      const source = this.audioContext.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(this.audioContext.destination);
      this.scheduledBuffers.push(source);

      source.onended = () => {
        this.setState('done');
      };

      this.nextStartTime = this.audioContext.currentTime;
      source.start(this.nextStartTime);
      this.setState('playing');
    } catch (err) {
      if ((err as Error).name === 'AbortError') {
        this.setState('idle');
      } else {
        this.setState('error');
      }
    }
  }

  stop() {
    this.abortController?.abort();
    this.abortController = null;
    for (const source of this.scheduledBuffers) {
      try { source.stop(); } catch { /* already stopped */ }
    }
    this.scheduledBuffers = [];
    if (this.audioContext) {
      try { this.audioContext.close(); } catch { /* already closed */ }
      this.audioContext = null;
    }
    this.setState('idle');
  }

  destroy() {
    this.stop();
    this.onStateChange = null;
  }
}
