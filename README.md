# electronics2-LABs

서울시립대학교 · 전자전기컴퓨터설계실험Ⅱ · 형종희 (2023440145, C조)

FPGA(Combo II-DLD S75, xc7s75fgga484-1) 기반 실험 제출 저장소. LAB별로 폴더가 나뉘어 있으며, 각 LAB 폴더 구조는 동일하다.

## 구성

- **[`LAB1/`](./LAB1)** — 조합논리 10종 (AND/OR/XOR 게이트 ~ 7세그먼트 디코더)
- **[`LAB2/`](./LAB2)** — 순차논리 8종 (업/다운 카운터 ~ 7세그먼트 자리 스캔)

각 LAB 폴더는 아래 구조를 공유한다.

```
LABn/
├── circuits/LABn-01 ~ LABn-NN/   각 회로의 RTL(src), 테스트벤치(sim), 제약 파일(constraints)
├── evidence/photos/               회로별 보드 동작 사진
├── evidence/videos/                회로별 보드 동작 영상
├── LABn_실험전보고서.html          실험 전 보고서
└── LABn_실험후보고서.html          실험 후 보고서
```

## 제출 태그

| LAB | 태그 | 커밋 |
|---|---|---|
| LAB1 | [`lab1-submit`](../../releases/tag/lab1-submit) | `3be4c53` |
| LAB2 | [`lab2-submit`](../../releases/tag/lab2-submit) | `dac086e` |

## 도구

Vivado 2026.1 (BASIC 라이선스) · Icarus Verilog 12.0 · VS Code
