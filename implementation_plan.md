# Tối Ưu Hóa Fmax Bộ Cộng FP16

## 1. Bối Cảnh & Mục Tiêu

Thiết kế hiện tại [ei_adder_fp16.v](file:///c:/Users/Admin/Downloads/rtl/ei_adder_fp16.v) sử dụng pipeline 4 stage với **Ripple-Carry Adder** (RCA), gây nghẽn critical path nghiêm trọng. Mục tiêu: **tối đa hóa Fmax** thông qua cải tiến kiến trúc arithmetic unit và tái cân bằng pipeline.

---

## 2. Phân Tích Critical Path Hiện Tại

### 2.1 Bộ cộng Ripple-Carry hiện tại

[ei_adderN.v](file:///c:/Users/Admin/Downloads/rtl/ei_adderN.v) xâu chuỗi N × `ei_full_adder`. Mỗi full adder có **2 gate delay** cho carry-out → **độ trễ = O(N)**.

| Module | Width | Delay (FA chains) |
|--------|-------|--------------------|
| `ei_adderN #(6)` | 6 | ~12 gate delays |
| `ei_adderN #(11)` | 11 | ~22 gate delays |
| `ei_adderN #(15)` | 15 | ~30 gate delays |
| `ei_subtractorN #(6)` | 6 | ~12 gate delays |
| `ei_subtractorN #(11)` | 11 | ~22 gate delays |
| `ei_subtractorN #(15)` | 15 | ~30 gate delays |

### 2.2 Critical Path từng Stage

| Stage | Các phép toán trên critical path | Ước tính depth |
|-------|----------------------------------|----------------|
| **S0** | `subtractorN#(11)` mantissa compare → compare logic → swap MUX | **~25 gate delays** |
| **S1** | `subtractorN#(6)` exp diff → barrel shifter (6 mức MUX) | **~18 gate delays** |
| **S2** | `adder/sub#(15)` → LZC(14) → left shift → `sub#(6)` exp_dec → underflow detect → `adder#(6)` shift_amt → barrel shift(6 mức) → MUX | **~60+ gate delays** ⚠️ |
| **S3** | `adder#(11)` round → `adder#(6)` exp_inc → overflow → 3× MUX chain | **~35 gate delays** |

> [!CAUTION]
> **Stage 2 là nút thắt cổ chai nghiêm trọng nhất**, với critical path ~60+ gate delays — gấp 3-4 lần các stage khác. Đây là yếu tố quyết định Fmax toàn pipeline.

### 2.3 Sơ đồ Critical Path Stage 2 (hiện tại)

```
big15, small15
     │
     ▼
subtractorN#(15) ──── 30 gate delays (ripple-carry)
     │
     ▼ sub15[13:0]
ei_lzcN#(14) ──────── ~14 gate delays (sequential scan)
     │
     ▼ lzc_sub4
left shift (<<) ────── ~4 gate delays
     │  ║
     │  ║ (parallel) subtractorN#(6) exp_big - lzc → ~12 delays
     │  ║
     ▼  ▼
MUX(same_sign) ─────── 1 gate delay
     │
     ▼
Underflow detect ───── ~2 gate delays
     │
     ▼
adderN#(6) shift_amt ─ ~12 gate delays
     │
     ▼
Barrel shift (6 mức) ─ ~6 gate delays
     │
     ▼
Output MUX ──────────── 1 gate delay
─────────────────────────────────────
TỔNG (serial path):    ~60+ gate delays
```

---

## 3. Chiến Lược Tối Ưu

Ba hướng tối ưu chính, xếp theo mức độ tác động:

### 🔴 Tối ưu 1: Carry-Lookahead Adder (CLA) — Tác động CAO

Thay thế **tất cả** `ei_adderN` (ripple-carry) và `ei_subtractorN` bằng phiên bản CLA.

| Đặc điểm | Ripple-Carry | CLA (4-bit groups) |
|-----------|-------------|---------------------|
| Delay cho N-bit | O(N) = ~2N gates | O(log₄N) ≈ ~6-8 gates |
| Delay 6-bit | ~12 | ~6 |
| Delay 11-bit | ~22 | ~8 |
| Delay 15-bit | ~30 | ~8 |
| Diện tích | Nhỏ nhất | ~1.5-2× lớn hơn |

**Nguyên lý CLA 4-bit block:**

```
Bit-level:  g_i = a_i & b_i       (generate)
            p_i = a_i ^ b_i       (propagate)

Group carry (4 bit, tính song song):
  c1 = g0 | (p0 & c0)
  c2 = g1 | (p1 & g0) | (p1 & p0 & c0)
  c3 = g2 | (p2 & g1) | (p2 & p1 & g0) | (p2 & p1 & p0 & c0)
  c4 = G  | (P & c0)

  Group_G = g3 | (p3 & g2) | (p3 & p2 & g1) | (p3 & p2 & p1 & g0)
  Group_P = p3 & p2 & p1 & p0

Sum:       sum_i = p_i ^ c_i
```

Với N=15, cần 4 nhóm CLA4 + 1 cấp look-ahead liên nhóm → **~8 gate delays** (vs 30 cho ripple-carry).

### 🟠 Tối ưu 2: Tái Cân Bằng Pipeline — Tác động CAO

Tách Stage 2 hiện tại (quá nặng) thành **2 stage**, tăng từ 4 lên **6 stage** tổ hợp (+ 1 output register = 6 thanh ghi):

```
HIỆN TẠI:  S0 ──▶ S1 ──▶ S2(nặng) ──▶ S3 ──▶ OUT
                          ▲ bottleneck

TỐI ƯU:   S0 ──▶ S1 ──▶ S2 ──▶ S3 ──▶ S4 ──▶ OUT
                   (tách S2 cũ thành S2+S3 mới)
```

**Pipeline mới (5 stage comb + output register):**

| Stage | Tên | Nội dung | Est. depth (CLA) |
|-------|-----|----------|-------------------|
| **S0** | Unpack + Compare + Swap | Unpack, NaN/Inf detect, exp_adj, mant 11-bit, compare exp & mant, swap big/small | **~7** |
| **S1** | Alignment | Extend 14-bit (+3 GRS), exp_diff, barrel shift small mantissa, sticky merge | **~9** |
| **S2** | Add/Sub + Partial Normalize | Add15 + Sub15 (song song, CLA), add normalize (shr1 + exp+1), sub LZC + sub left shift + exp_sub | **~12** |
| **S3** | Choose + Underflow | MUX chọn add/sub, underflow detect, shift_amt calc, barrel shift to subnormal, sticky merge | **~13** |
| **S4** | Round + Pack + Final | RNE rounding (GRS → inc → add11), pack {sign,exp,frac}, overflow → ∞, priority MUX (NaN > Inf > Normal) | **~12** |
| — | Output Register | `regN#(16)` latch kết quả | — |

### 🟡 Tối ưu 3: LZC Tree + Barrel Shifter cấu trúc — Tác động TRUNG BÌNH

**LZC hiện tại** ([ei_lzcN.v](file:///c:/Users/Admin/Downloads/rtl/ei_lzcN.v)): dùng vòng `for` tuần tự → synthesis thành priority encoder chain = O(N).

**LZC tree**: chia đôi đệ quy, mỗi nửa báo `count` + `all_zero` → O(log₂N).

| | LZC Sequential | LZC Tree |
|---|----------------|----------|
| 14-bit delay | ~14 mức logic | ~4 mức logic |

**Barrel shifter**: [ei_shr_varN_sticky.v](file:///c:/Users/Admin/Downloads/rtl/ei_shr_varN_sticky.v) hiện dùng behavioral `>>` và vòng `for` cho sticky — phụ thuộc vào synthesis tool. Thiết kế cấu trúc logarithmic (multi-stage MUX) cho kết quả nhất quán hơn.

---

## 4. Ước Tính Cải Thiện Tổng Hợp

| Cấu hình | Max Stage Depth | Fmax tương đối |
|-----------|-----------------|----------------|
| **Hiện tại** (RCA, 4 stage) | ~60 gate delays | **1.0×** (baseline) |
| CLA only (giữ 4 stage) | ~22 gate delays | **~2.7×** |
| **CLA + Pipeline 6 stage** | ~13 gate delays | **~4.6×** |
| CLA + Pipeline + LZC tree | ~12 gate delays | **~5.0×** |

> [!IMPORTANT]
> Tradeoff: Latency tăng từ 4 → 6 cycles, nhưng throughput vẫn là 1 result/cycle. Diện tích tăng do CLA và thêm pipeline registers (~100 flip-flops thêm).

---

## 5. Proposed Changes

### Arithmetic Modules (New)

#### [NEW] [ei_cla_group4.v](file:///c:/Users/Admin/Downloads/rtl/ei_cla_group4.v)
- Block CLA 4-bit: tính carry song song cho 4 bit
- Input: `a[3:0]`, `b[3:0]`, `cin`
- Output: `sum[3:0]`, `cout`, `group_P`, `group_G`
- Gate-level implementation (AND, OR, XOR — không dùng `+`)

#### [NEW] [ei_adderN_cla.v](file:///c:/Users/Admin/Downloads/rtl/ei_adderN_cla.v)
- CLA adder N-bit tham số hóa, chia thành các nhóm 4-bit
- Cấp look-ahead thứ 2 tính carry-in cho từng nhóm song song
- Interface giống hệt `ei_adderN`: `a`, `b` → `sum`, `cout`
- Hỗ trợ WIDTH không chia hết cho 4 (padding nội bộ)

#### [NEW] [ei_subtractorN_cla.v](file:///c:/Users/Admin/Downloads/rtl/ei_subtractorN_cla.v)
- CLA subtractor: `a - b = a + ~b + 1` sử dụng `ei_adderN_cla` nội bộ
- Interface giống hệt `ei_subtractorN`: `a`, `b` → `diff`, `borrow`

---

### Utility Modules (Modified)

#### [NEW] [ei_lzcN_tree.v](file:///c:/Users/Admin/Downloads/rtl/ei_lzcN_tree.v)
- Leading Zero Counter kiểu cây đệ quy
- Chia input thành 2 nửa, mỗi nửa đệ quy tính `count` + `all_zero`
- Base case: 2-bit hoặc 1-bit
- Merge: nếu nửa cao `all_zero` → `count = count_high_width + count_low`, ngược lại → `count = count_high`
- O(log₂N) depth thay vì O(N)

#### [NEW] [ei_barrel_shr_sticky.v](file:///c:/Users/Admin/Downloads/rtl/ei_barrel_shr_sticky.v)
- Barrel shifter phải cấu trúc logarithmic
- Mỗi bit của `shamt` điều khiển 1 tầng MUX: shift 1, 2, 4, 8, ...
- Sticky bit: OR-tree song song của các bit bị dịch ra
- Kết quả synthesis nhất quán, không phụ thuộc tool

---

### Top-Level (New Optimized Version)

#### [NEW] [ei_adder_fp16_v2.v](file:///c:/Users/Admin/Downloads/rtl/ei_adder_fp16_v2.v)

Pipeline 6 stage tối ưu. Chi tiết từng stage:

**Stage 0: Unpack + Special + Compare + Swap** (tương tự hiện tại)
- Giữ nguyên logic, thay `ei_subtractorN` → `ei_subtractorN_cla`
- Instances: 2× `ei_fp16_is_nan`, 2× `ei_fp16_is_inf`, 3× `ei_subtractorN_cla` (#6, #6, #11), 1× `ei_mux16`, 7× `ei_muxN`

**Stage 1: Alignment** (tương tự hiện tại)
- Thay `ei_subtractorN` → `ei_subtractorN_cla`
- Thay `ei_shr_varN_sticky` → `ei_barrel_shr_sticky`
- Instances: 1× `ei_subtractorN_cla#(6)`, 1× `ei_barrel_shr_sticky#(14,6)`

**Stage 2: Add/Sub + Partial Normalize** (TÁCH TỪ S2 CŨ — PHẦN 1)
- Add/Sub 15-bit song song (CLA)
- Add path: detect carry, shr1 normalize, exp+1
- Sub path: LZC tree + left shift + exp - lzc
- **Tất cả tính toán normalize, CHƯA xử lý underflow**
- Instances: 1× `ei_adderN_cla#(15)`, 1× `ei_subtractorN_cla#(15)`, 1× `ei_lzcN_tree#(14)`, 1× `ei_adderN_cla#(6)`, 1× `ei_subtractorN_cla#(6)`, 2× `ei_muxN`

**Stage 3: Choose Result + Underflow Handling** (TÁCH TỪ S2 CŨ — PHẦN 2)
- MUX chọn kết quả add/sub theo `same_sign`
- Underflow detection (`exp_neg`, `exp_is_0`, `exp_is_1`)
- Shift amount calculation
- Barrel shift to subnormal + sticky
- Xác định `sign_core`, `exp_pre_round`, `mant_pre_round`
- Instances: 2× `ei_muxN`, 1× `ei_subtractorN_cla#(6)`, 1× `ei_adderN_cla#(6)`, 1× `ei_barrel_shr_sticky#(14,6)`

**Stage 4: RNE Round + Pack + Overflow + Final MUX** (tương tự S3 cũ)
- Giữ nguyên logic, thay adder → CLA
- Instances: 1× `ei_adderN_cla#(11)`, 1× `ei_adderN_cla#(6)`, 3× `ei_mux16`

**Output Register**: `regN#(16)`

---

### Pipeline Register Budget

| Register | Width (bits) | Nội dung chính |
|----------|-------------|----------------|
| R01 | 70 | is_nan, is_inf, same_sign, sign_big, sum_nan, sum_inf, exp_big6, exp_small6, mant_big_11, mant_small_11 |
| R12 | 70 | is_nan, is_inf, same_sign, sign_big, sum_nan, sum_inf, exp_big6, mant_big_align14, mant_small_align14 |
| R23 | ~90 | is_nan, is_inf, same_sign, sign_big, sum_nan, sum_inf, add/sub results, LZC count, normalized mants, exps, flags |
| R34 | ~57 | is_nan, is_inf, sign_core, is_normal_out, exp_pre_round6, mant_pre_round14, core_zero |
| R_OUT | 16 | sum_out[15:0] |
| **Tổng** | **~303** | vs hiện tại ~213 (+90 FFs, ~42% tăng) |

---

## User Review Required

> [!IMPORTANT]
> **Latency tradeoff**: Pipeline mới có **latency 6 cycles** (vs 4 hiện tại). Throughput vẫn là 1 result/cycle. Điều này có chấp nhận được trong hệ thống của bạn không?

> [!IMPORTANT]  
> **Giữ nguyên bản cũ**: Tôi dự định tạo file mới `ei_adder_fp16_v2.v` (không sửa file gốc). Các module mới (`ei_adderN_cla`, `ei_subtractorN_cla`, `ei_lzcN_tree`, `ei_barrel_shr_sticky`) cũng tạo mới, không sửa module cũ. Bạn có muốn cách tiếp cận khác không?

> [!WARNING]
> **Diện tích**: CLA adder lớn hơn ripple-carry ~1.5-2× (do fan-out carry logic). Tổng diện tích tăng thêm do cả CLA lẫn thêm pipeline registers. Bạn có ràng buộc về diện tích/resource FPGA không?

## Open Questions

1. **Target platform**: Bạn đang target FPGA (Xilinx/Intel) hay ASIC? Điều này ảnh hưởng đến cách tối ưu CLA (FPGA có fast carry chain sẵn, ASIC cần gate-level CLA).

2. **Fmax target**: Bạn có con số Fmax mục tiêu cụ thể không? (VD: 200MHz, 500MHz, ...)

3. **Ưu tiên**: Nếu phải chọn, bạn ưu tiên:
   - **(A)** Fmax cao nhất có thể (chấp nhận latency + diện tích tăng)
   - **(B)** Cân bằng Fmax/latency/diện tích

---

## Verification Plan

### Automated Tests
- Tạo testbench so sánh output `ei_adder_fp16_v2` với `ei_adder_fp16` (bản gốc) trên cùng bộ input
- Test vector bao gồm: normal+normal, subnormal, NaN, ±Inf, ±0, overflow, underflow, rounding ties
- Chạy qua Icarus Verilog hoặc Vivado simulator

### Manual Verification
- Tổng hợp (synthesize) cả 2 bản trên cùng target → so sánh Fmax report
- So sánh resource utilization (LUTs, FFs, carry chains)
