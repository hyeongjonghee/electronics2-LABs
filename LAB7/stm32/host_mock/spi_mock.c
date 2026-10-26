/* LAB7 MCU 모의 실행: 과제 코드(ece2_474_routine.c)를 그대로 컴파일해 PC에서 돌린다.
 *
 *  ./mock_tx  <출력 hex> <초>   송신(마스터) 코드.  1 ms씩 시간을 흘리며 메인 루프를 돌리고,
 *                                HAL_SPI_Transmit으로 나간 바이트를 hex 파일(한 줄 한 바이트)에 남긴다.
 *                                -> FPGA 테스트벤치(과제10)가 이 파일을 읽어 SPI 파형으로 만들어 보낸다.
 *                                또 CS(PB6)가 LOW인 동안에만 Transmit이 불렸는지, SPI1이 모드 0·MSB 먼저인지 검사한다.
 *  ./mock_rx  <입력 hex>         수신(슬레이브) 코드.  HAL_SPI_Receive가 hex 파일의 바이트를 차례로 돌려주고,
 *                                다 쓰면 2000 ms 뒤 HAL_TIMEOUT을 돌려준다(송신 측이 멈춘 상황).
 *                                -> 과제9(MCU->MCU)는 mock_tx의 출력, 과제11(FPGA->MCU)은 FPGA TB가 받은 바이트를 넣는다.
 *                                또 ece2_474_init이 SPI1을 슬레이브 + NSS 하드웨어 입력으로 바꾸고 PA4를 AF5로 설정했는지 검사한다.
 *  표준 출력 = MCU VCP(UART2, printf) 출력.  "#"으로 시작하는 줄은 모의 실행기의 검사 기록. */
#include <stdlib.h>
#include <string.h>
#include "main.h"
#include "ece2_474.h"

PERIPH_TypeDef mock_tim6 = {6}, mock_usart2 = {2}, mock_usart3 = {3}, mock_spi1 = {1};
GPIO_TypeDef mock_gpioa = {0xA}, mock_gpiob = {0xB}, mock_gpioc = {0xC};
TIM_HandleTypeDef htim6 = {TIM6}, htim3 = {0};
UART_HandleTypeDef huart2 = {USART2}, huart3 = {USART3};
SPI_HandleTypeDef hspi1; I2C_HandleTypeDef hi2c1;

static uint32_t tick = 0;
static int cs_low = 0, errors = 0, pa4_af5 = 0, deinit_seen = 0;
static FILE *hexf;

#define CHECK(c, ...) do { if (!(c)) { printf("# CHECK FAIL: " __VA_ARGS__); printf("\n"); errors++; } } while (0)

uint32_t HAL_GetTick(void) { return tick; }
void Error_Handler(void) { printf("# Error_Handler\n"); exit(2); }
HAL_StatusTypeDef HAL_TIM_Base_Start_IT(TIM_HandleTypeDef *h) { (void)h; return HAL_OK; }
HAL_StatusTypeDef HAL_UART_Receive_IT(UART_HandleTypeDef *h, uint8_t *p, uint16_t n) { (void)h; (void)p; (void)n; return HAL_OK; }
HAL_StatusTypeDef HAL_UART_Transmit(UART_HandleTypeDef *h, const uint8_t *p, uint16_t n, uint32_t t) { (void)h; (void)p; (void)n; (void)t; return HAL_OK; }

void HAL_GPIO_WritePin(GPIO_TypeDef *port, uint16_t pin, GPIO_PinState s)
{
    if (port == SPI_CS_ece2_GPIO_Port && pin == SPI_CS_ece2_Pin) cs_low = (s == GPIO_PIN_RESET);
}
void HAL_GPIO_Init(GPIO_TypeDef *port, GPIO_InitTypeDef *g)
{
    if (port == GPIOA && g->Pin == GPIO_PIN_4) {
        pa4_af5 = (g->Mode == GPIO_MODE_AF_PP && g->Alternate == GPIO_AF5_SPI1);
        printf("# PA4 init: mode=%s pull=%s AF=%u\n", g->Mode == GPIO_MODE_AF_PP ? "AF_PP" : "?",
               g->Pull == GPIO_PULLUP ? "UP" : "?", (unsigned)g->Alternate);
    }
}
HAL_StatusTypeDef HAL_SPI_DeInit(SPI_HandleTypeDef *h) { h->initialized = 0; deinit_seen = 1; return HAL_OK; }
HAL_StatusTypeDef HAL_SPI_Init(SPI_HandleTypeDef *h)
{
    h->initialized = 1;
    printf("# SPI1 init: %s, NSS=%s, CPOL=%u CPHA=%u (mode 0), %u-bit, %s first, prescaler=%u\n",
           h->Init.Mode == SPI_MODE_MASTER ? "MASTER" : "SLAVE",
           h->Init.NSS == SPI_NSS_SOFT ? "SOFT" : "HARD_INPUT",
           (unsigned)h->Init.CLKPolarity, (unsigned)h->Init.CLKPhase, (unsigned)h->Init.DataSize,
           h->Init.FirstBit == SPI_FIRSTBIT_MSB ? "MSB" : "LSB", (unsigned)h->Init.BaudRatePrescaler);
    return HAL_OK;
}
static void check_mode0(SPI_HandleTypeDef *h)
{
    CHECK(h->initialized, "SPI not initialized");
    CHECK(h->Init.CLKPolarity == SPI_POLARITY_LOW && h->Init.CLKPhase == SPI_PHASE_1EDGE, "not mode 0");
    CHECK(h->Init.DataSize == SPI_DATASIZE_8BIT && h->Init.FirstBit == SPI_FIRSTBIT_MSB, "not 8-bit MSB first");
}
HAL_StatusTypeDef HAL_SPI_Transmit(SPI_HandleTypeDef *h, const uint8_t *p, uint16_t n, uint32_t t)
{
    (void)t;
    check_mode0(h);
    CHECK(h->Init.Mode == SPI_MODE_MASTER, "Transmit called but SPI1 is not master");
    CHECK(cs_low, "Transmit while CS(PB6) is HIGH at %u ms", (unsigned)tick);
    for (uint16_t i = 0; i < n; i++) fprintf(hexf, "%02x\n", p[i]);
    return HAL_OK;
}
HAL_StatusTypeDef HAL_SPI_Receive(SPI_HandleTypeDef *h, uint8_t *p, uint16_t n, uint32_t t)
{
    check_mode0(h);
    CHECK(h->Init.Mode == SPI_MODE_SLAVE && h->Init.NSS == SPI_NSS_HARD_INPUT, "Receive but SPI1 is not slave/NSS hard");
    CHECK(pa4_af5, "PA4 is not configured as SPI1 NSS (AF5)");
    for (uint16_t i = 0; i < n; i++) {
        unsigned v;
        if (fscanf(hexf, "%x", &v) != 1) { tick += t; return HAL_TIMEOUT; }   /* 보내는 쪽이 없음: t ms 기다리다 끝 */
        p[i] = (uint8_t)v;
    }
    tick += 1000U;                                                             /* 송신 측이 1초마다 보냄 */
    return HAL_OK;
}

int main(int argc, char **argv)
{
    /* main.c MX_SPI1_Init과 같은 기본값: 마스터, 2LINES, 8비트, CPOL 0, CPHA 1EDGE, NSS SOFT, /128, MSB */
    hspi1.Instance = SPI1;
    hspi1.Init = (SPI_InitTypeDef){ SPI_MODE_MASTER, SPI_DIRECTION_2LINES, SPI_DATASIZE_8BIT,
                                    SPI_POLARITY_LOW, SPI_PHASE_1EDGE, SPI_NSS_SOFT, SPI_BAUDRATEPRESCALER_128, SPI_FIRSTBIT_MSB };
    HAL_SPI_Init(&hspi1);
    printf("# SCK = 100 MHz / %u = %.2f kHz\n", (unsigned)hspi1.Init.BaudRatePrescaler, 100000.0 / hspi1.Init.BaudRatePrescaler);
#ifdef MOCK_RX
    hexf = fopen(argc > 1 ? argv[1] : "spi_in.hex", "r");
    if (!hexf) { printf("# cannot open input\n"); return 2; }
    ece2_474_init();
    if (!deinit_seen) printf("# note: HAL_SPI_DeInit not called\n");
    int timeouts = 0;
    while (timeouts < 1) {                                 /* 입력을 다 쓰고 타임아웃 한 번 나오면 끝 */
        uint32_t before = tick;
        polling_routine();
        if (tick - before >= 2000U) timeouts++;
    }
#else
    hexf = fopen(argc > 1 ? argv[1] : "spi1_tx.hex", "w");
    unsigned secs = argc > 2 ? (unsigned)atoi(argv[2]) : 4U;
    ece2_474_init();
    for (tick = 0; tick <= secs * 1000U; tick++) polling_routine();   /* 메인 루프가 1 ms에 한 번 이상 돈다고 가정 */
#endif
    fclose(hexf);
    printf("# %s: %d check failures\n", errors ? "FAIL" : "PASS", errors);
    return errors ? 1 : 0;
}
