/* 가짜 HAL + 메인 루프. stdin = PC Serial Monitor 입력, stdout = VCP 출력,
 * UART3로 나간 바이트는 uart3_tx.hex(한 줄에 한 바이트)로 기록 -> FPGA TB가 이 파일을 읽어 직렬로 보낸다. */
#include "main.h"
#include "ece2_474.h"
PERIPH_TypeDef mock_tim6 = {6}, mock_usart2 = {2}, mock_usart3 = {3};
TIM_HandleTypeDef htim6 = {TIM6}, htim3 = {0};
UART_HandleTypeDef huart2 = {USART2}, huart3 = {USART3};
SPI_HandleTypeDef hspi1; I2C_HandleTypeDef hi2c1;
static FILE *tx3;
HAL_StatusTypeDef HAL_UART_Transmit(UART_HandleTypeDef *h, const uint8_t *p, uint16_t n, uint32_t t)
{
    (void)t;
    if (h != &huart3) return HAL_ERROR;
    for (uint16_t i = 0; i < n; i++) fprintf(tx3, "%02x\n", p[i]);
    return HAL_OK;
}
int main(int argc, char **argv)
{
    tx3 = fopen(argc > 1 ? argv[1] : "uart3_tx.hex", "w");
    ece2_474_init();
    while (!feof(stdin)) polling_routine();   /* 실제 보드: 무한 루프. 모의: 입력이 끝나면 종료 */
    fclose(tx3);
    return 0;
}
