# Debug Session: model-warmup-delay

Status: OPEN

## Symptom
- First request after startup is slow.
- Later requests also become slow again after some idle time.
- Dummy warm-up during `setup` does not keep the model responsive.

## Expected
- `setup` should download and warm the model once.
- `webchat` and `api` should get fast responses after setup.
- The model should remain warm while the Colab runtime stays active.

## Hypotheses
1. Warm-up runs before the model server is actually ready.
2. `webchat` and `api` use a path that bypasses the earlier warm-up.
3. Background keep-alive requests are not running or not reaching the right endpoint.
4. Requests do not set a keep-alive duration, so the model unloads after idle time.
5. Another script path or restart clears the warmed model state after setup.

## Evidence Log
- Static inspection:
  - `warm_up_model()` used `ollama run`, while `webchat` and browser/API clients use `POST /api/chat`.
  - Web chat clients did not send per-request `keep_alive`, so they relied only on server defaults.
  - Keep-alive loop also used `ollama run` and its duplicate-process check looked for `keep_alive.sh`, but the actual loop was started with `bash -c`, so repeated `setup` could start extra loops.
  - External docs for Ollama API state that API requests default to `keep_alive=5m` unless overridden, which matches the user's "slow again after some idle time" symptom.

## Changes Applied
- Default server keep-alive changed from `24h` to `-1` so a single-model Colab runtime keeps the model loaded until stop/restart.
- Warm-up changed to an HTTP `POST /api/chat` request with explicit `keep_alive`.
- Web chat clients now send `keep_alive` on every request.
- `api` and `webchat` modes now trigger a warm-up before presenting the endpoint/UI.
- Keep-alive loop now uses the same HTTP path and avoids duplicate background loops; it is skipped entirely when `keep_alive=-1`.
- Added runtime instrumentation logs in `/tmp/model_runtime_debug.log`.

## Next Step
- User verifies in Colab whether first request is warm after `setup`, and whether later requests stay warm after idle time.
