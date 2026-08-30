# AC Validation Report — selfcheck MVP

**Updated**: 2026-08-31  
**Source of truth**: GitHub Actions + the concrete test/file evidence listed below  
**Overall**: ⚠️ **PARTIAL PASS — device acceptance is still incomplete**

This report intentionally does **not** treat enum existence, in-memory execution speed, or a lack of network calls as proof of device-level acceptance. A requirement is marked PASS only when the relevant production path is exercised by automated tests. Physical camera, permission, OCR, latency, and airplane-mode requirements remain PENDING until they are verified on a device.

CI success means the automated suite passed; it does not convert PENDING device acceptance into PASS.

---

## Acceptance status

| AC | Requirement | Status | Evidence / remaining gate |
|---|---|---|---|
| AC-01 | バーコード+価格同時 → 3秒以内に結果 | ⏳ PENDING | Compare/use-case timing is not camera-to-result timing. Real camera/JAN/OCR is implemented in #1 / PR #35, but physical-device end-to-end latency still needs measurement. |
| AC-02 | バーコードのみでSKU確定 → 価格安定次第比較完了 | ✅ PASS (automated) | `test/integration/ac_state_machine_validation_test.dart` drives `ScanCoordinator`: barcode → `waitingPrice` → three stable readings → `result` and persisted price. |
| AC-03 | 未知JAN → 文字入力なしで暫定SKU作成 | ✅ PASS (automated) | Repository/coordinator tests verify unknown JAN creates a provisional product without text input. |
| AC-04 | 同一JANの履歴だけ使用 | ✅ PASS (automated) | Repository/use-case tests filter history by `productId`. |
| AC-05 | 同一SKU+同一価格の短時間連続 → 重複防止 | 🔧 FIX IN PROGRESS | Fixed-bucket tests were insufficient. #7 / PR #31 adds a rolling five-minute query and the 10:04:59 → 10:05:01 boundary regression. Keep non-PASS until that change lands. |
| AC-06 | 機内モードで全操作動作 | ⏳ PENDING | Local SQLite and on-device ML design are offline-capable, but unit tests do not prove physical airplane-mode camera/JAN/OCR behavior. Requires device acceptance after #1. |
| AC-07 | カメラ画像がデータ領域に残らない | ⚠️ PARTIAL | Static/data-model evidence shows no image column/path and PR #35 processes frames in memory. Physical-device filesystem/cache inspection is still required. |
| AC-08 | バーコード未検出 → 案内表示 / recovery | ✅ PASS (automated) | `ac_state_machine_validation_test.dart` exercises price-only → `noProduct` → scanning recovery and proves the stale price cannot leak into the next JAN. |
| AC-09 | 価格未検出 → 認識継続 | ⚠️ PARTIAL | Coordinator lifecycle tests cover state recovery, but real camera/OCR continuation requires device acceptance with PR #35. |
| AC-10 | 中央値→差額・差率・ラベル正計算 | 🔧 FIX IN PROGRESS | Existing odd-count tests pass, but the prior report missed the even-count bug. #5 / PR #32 adds the mathematical even-count median regression. Keep non-PASS until that change lands. |
| AC-11 | 過去0件 → 初回価格表示 | ✅ PASS (automated) | Use-case/result tests verify `firstPrice` with no label. |
| AC-12 | 再スキャン優先（安全性） | 🔧 FIX IN PROGRESS | Coordinator tests prove transient unstable OCR is not persisted, but #52 found that an explicit unit price such as `100g当たり ¥198` can outrank a bare product price. PR #53 adds fail-closed unit-price rejection. Keep non-PASS until that regression is green and the change lands. |

---

## Production-path tests added for #10

`test/integration/ac_state_machine_validation_test.dart` provides concrete state-machine evidence for the safety-critical paths that were previously represented by weaker tests:

1. **AC-02 barcode-first** — `ScanCoordinator` actually enters `waitingPrice`, remains there for the first two readings, reaches `result` on the third matching reading, and persists only that price.
2. **AC-12 transient OCR error** — a wrong price observed before the JAN does not create a product or observation; the later stable price is the only persisted value.
3. **AC-08 stale-price isolation** — a price-only `noProduct` cycle returns to scanning and the next JAN waits for a new price rather than using the previous one.

These tests exercise the application state machine and real Drift-backed test repository. They still use deterministic test adapters rather than a physical camera, so they cannot satisfy the device-only gates listed above. Price-parser safety is separately tracked by #52 / PR #53.

---

## What no longer counts as acceptance evidence

The following are useful unit/integration checks, but are **not sufficient by themselves** for the named acceptance condition:

- A `CompareUseCase` call completing in under three seconds is not AC-01 camera-to-result latency.
- Merely constructing or referencing `ScanState.waitingPrice` / `ScanState.result` is not proof of a state transition.
- Having no network dependency in the repository is not proof that the complete app works in airplane mode.
- Having no image field in a database model is not, by itself, proof that camera/plugin caches never persist an image.
- `PriceStabilizer` unit tests alone are not proof that the coordinator cannot bypass stabilization.
- Three identical OCR readings are not proof that the recognized number is the product's selling price; explicit unit-price context must also be rejected.

---

## Device acceptance still required

Before declaring the MVP acceptance suite fully PASS, record physical-device evidence for at least:

- camera permission allow / deny / retry
- camera preview and lifecycle resume/pause
- EAN-13 / EAN-8 detection feeding `ScanCoordinator`
- price OCR feeding the stabilizer without cloud/network access
- barcode + price to visible result latency for AC-01
- the same path with airplane mode enabled for AC-06
- app storage/cache inspection confirming camera frames are not retained for AC-07

Until those checks are recorded, the correct overall disposition is **PARTIAL PASS / DEVICE ACCEPTANCE PENDING**.
