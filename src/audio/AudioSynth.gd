class_name AudioSynth
extends RefCounted

## Procedural audio synthesis utility. Generates AudioStreamWAV buffers from code
## so the game ships with zero audio assets. Replace synthesized outputs with
## real .ogg/.wav files later by swapping in the Workshop or audio/ folders.

const SAMPLE_RATE := 44100

## Generate a pure tone with envelope. Returns AudioStreamWAV.
static func tone(freq: float, duration: float, volume: float = 0.5, wave_type: String = "sine") -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var sample: float
		match wave_type:
			"sine": sample = sin(t * freq * TAU)
			"square": sample = 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
			"saw": sample = 2.0 * fmod(t * freq, 1.0) - 1.0
			"triangle": sample = 2.0 * abs(2.0 * fmod(t * freq, 1.0) - 1.0) - 1.0
			_: sample = sin(t * freq * TAU)
		# Envelope: fast attack, exponential decay.
		var env := 1.0
		var attack := 0.005
		if t < attack:
			env = t / attack
		else:
			env = exp(-(t - attack) * 4.0)
		sample *= env * volume
		var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, false)

## Generate white noise burst with envelope.
static func noise(duration: float, volume: float = 0.5, filtered: bool = false) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var prev: float = 0.0
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var raw := randf_range(-1.0, 1.0)
		if filtered:
			raw = prev * 0.95 + raw * 0.05
			prev = raw
		var env := exp(-t * 8.0)
		raw *= env * volume
		var quantized := int(clamp(raw, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, false)

## Generate a descending slide (slide whistle effect).
static func slide(start_freq: float, end_freq: float, duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		var freq := lerpf(start_freq, end_freq, progress)
		var sample := sin(t * freq * TAU)
		var env := 1.0
		if t < 0.01:
			env = t / 0.01
		elif t > duration - 0.05:
			env = (duration - t) / 0.05
		sample *= env * volume
		var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, false)

## Generate an ascending chime sequence (prestige).
static func chime(notes: Array, note_duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var total_samples := int(notes.size() * note_duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(total_samples * 2)
	for note_idx in notes.size():
		var freq: float = notes[note_idx]
		var start_sample := int(note_idx * note_duration * SAMPLE_RATE)
		var note_samples := int(note_duration * SAMPLE_RATE)
		for i in note_samples:
			var t := float(i) / SAMPLE_RATE
			var sample := sin(t * freq * TAU)
			# Add a harmonic for richness.
			sample += sin(t * freq * 2 * TAU) * 0.3
			var env := exp(-t * 3.0)
			if t < 0.01:
				env = t / 0.01
			sample *= env * volume * 0.7
			var idx := (start_sample + i) * 2
			if idx < data.size() - 1:
				var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
				data.encode_s16(idx, quantized)
	return _make_stream(data, false)

## Generate a reversed version of a stream (for 666 reversed piano).
static func reversed(source: AudioStreamWAV) -> AudioStreamWAV:
	var src_data := source.data
	var samples := src_data.size() / 2
	var data := PackedByteArray()
	data.resize(src_data.size())
	for i in samples:
		var src_idx := (samples - 1 - i) * 2
		var dst_idx := i * 2
		data.encode_s16(dst_idx, src_data.decode_s16(src_idx))
	return _make_stream(data, false)

## Generate a short looping pad/drone for music stems.
static func loop(freqs: Array, duration: float, volume: float = 0.3, wave_type: String = "sine") -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var sample: float = 0.0
		for freq in freqs:
			match wave_type:
				"sine": sample += sin(t * freq * TAU)
				"triangle": sample += 2.0 * abs(2.0 * fmod(t * freq, 1.0) - 1.0) - 1.0
				_: sample += sin(t * freq * TAU)
		sample /= float(freqs.size())
		# Slow LFO for gentle movement.
		var lfo := 0.85 + 0.15 * sin(t * 0.5 * TAU)
		sample *= lfo * volume
		var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, true)

## Generate a bass pulse loop (rhythmic low-end).
static func bass_loop(freq: float, duration: float, bpm: float, volume: float = 0.3) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var beat_interval := 60.0 / bpm
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var beat_pos := fmod(t, beat_interval)
		var sample := sin(t * freq * TAU)
		# Pulse envelope — sharp attack, quick decay per beat.
		var env := exp(-beat_pos * 12.0)
		sample *= env * volume
		var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, true)

## Generate an arpeggiated synth loop.
static func arp_loop(notes: Array, note_duration: float, duration: float, volume: float = 0.25) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var total_notes := int(duration / note_duration)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var note_idx := int(t / note_duration) % notes.size()
		var note_t := fmod(t, note_duration)
		var freq: float = notes[note_idx]
		var sample := sin(t * freq * TAU)
		sample += sin(t * freq * 2 * TAU) * 0.2
		var env := exp(-note_t * 6.0)
		if note_t < 0.005:
			env = note_t / 0.005
		sample *= env * volume
		var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, true)

## Generate a full drum + synth loop (the "banger" stem).
static func full_loop(duration: float, volume: float = 0.25) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var bpm := 120.0
	var beat_interval := 60.0 / bpm
	# Chord progression (Am - F - C - G).
	var chords: Array = [
		[220.0, 261.63, 329.63],
		[174.61, 220.0, 261.63],
		[261.63, 329.63, 392.0],
		[196.0, 246.94, 293.66],
	]
	var chord_duration := duration / chords.size()
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var chord_idx := int(t / chord_duration) % chords.size()
		var chord: Array = chords[chord_idx]
		var sample: float = 0.0
		# Chord pad.
		for freq in chord:
			sample += sin(t * freq * TAU) * 0.2
		# Kick drum on beats.
		var beat_pos := fmod(t, beat_interval)
		if beat_pos < 0.05:
			sample += sin(beat_pos * 60.0 * TAU) * exp(-beat_pos * 30.0) * 0.5
		# Hi-hat on off-beats.
		var half_beat := fmod(t, beat_interval * 0.5)
		if half_beat > beat_interval * 0.45:
			sample += (randf() * 2.0 - 1.0) * 0.1
		sample = clamp(sample, -1.0, 1.0) * volume
		var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, true)

## Generate an alarm klaxon (for 2319).
static func klaxon(duration: float, volume: float = 0.5) -> AudioStreamWAV:
	var samples := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var lfo := sin(t * 4.0 * TAU)
		var freq := 440.0 + lfo * 200.0
		var sample := sin(t * freq * TAU) * 0.7
		sample += sin(t * freq * 2 * TAU) * 0.2
		# Square-ish for harshness.
		sample = clamp(sample * 1.5, -1.0, 1.0)
		var env := 1.0
		if t < 0.02:
			env = t / 0.02
		elif t > duration - 0.05:
			env = (duration - t) / 0.05
		sample *= env * volume
		var quantized := int(clamp(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, quantized)
	return _make_stream(data, false)

static func _make_stream(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	return stream
