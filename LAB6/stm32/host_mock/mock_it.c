/* 인터럽트 버전 모의: stdin 바이트를 '연속으로' ISR에 넣어 오버런 없이 묶음 처리되는지 확인 */
#include "main.h"
#include "ece2_474.h"
PERIPH_TypeDef mock_tim6 = {6}, mock_usart2 = {2}, mock_usart3 = {3};
TIM_HandleTypeDef htim6 = {TIM6}, htim3 = {0};
UART_HandleTypeDef huart2 = {USART2}, huart3 = {USART3};
SPI_HandleTypeDef hspi1; I2C_HandleTypeDef hi2c1;
static FILE *tx3; static uint32_t tick = 0; static uint8_t *rxp = 0;
uint32_t HAL_GetTick(void) { return tick; }
HAL_StatusTypeDef HAL_UART_Receive_IT(UART_HandleTypeDef *h, uint8_t *p, uint16_t n) { (void)h; (void)n; rxp = p; return HAL_OK; }
HAL_StatusTypeDef HAL_UART_Transmit(UART_HandleTypeDef *h, const uint8_t *p, uint16_t n, uint32_t t)
{ (void)t; if (h != &huart3) return HAL_ERROR; for (uint16_t i = 0; i < n; i++) fprintf(tx3, "%02x\n", p[i]); tick += 1; return HAL_OK; }
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart);
int main(int argc, char **argv)
{
    tx3 = fopen(argc > 1 ? argv[1] : "uart3_tx.hex", "w");
    ece2_474_init();
    int c; int burst_gap = 0;
    /* 입력: 줄 하나 = PC가 한 번에 보낸 묶음. 묶음 안 바이트는 1 ms 간격(9600bps)으로 도착 */
    while ((c = getchar()) != EOF) {
        if (c == '\n') { for (int k = 0; k < 100; k++) { tick++; polling_routine(); } continue; }
        *rxp = (uint8_t)c; HAL_UART_RxCpltCallback(&huart2);   /* 1바이트 도착 */
        tick++; polling_routine();                              /* 메인 루프가 1 ms에 한 번 이상 돈다고 가정 */
        (void)burst_gap;
    }
    for (int k = 0; k < 100; k++) { tick++; polling_routine(); }
    fclose(tx3); return 0;
}
