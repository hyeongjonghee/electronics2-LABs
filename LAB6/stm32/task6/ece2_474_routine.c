/*
 * 초기화·폴링·인터럽트 실습 템플릿입니다. CubeMX 자동 생성 파일이 아닙니다.
 * 학생은 아래 함수의 '실습 코드 작성' 부분을 채웁니다.
 * 아래쪽 HAL 콜백은 자동 생성된 인터럽트 처리 코드와 실습 함수를 연결합니다.
 * 인터럽트에서는 처리할 일을 기록하고 빠르게 돌아옵니다.
 * 인터럽트 함수 안에서는 HAL_Delay, scanf, getchar, printf를 사용하지 않습니다.
 */
#include "ece2_474.h"
#include "main.h"
/* 주변장치 변수의 extern 선언은 ece2_474.h에 있습니다. */

/* UART 인터럽트 수신 실습 때 필요한 버퍼의 주석을 해제합니다.
 * 파일 범위에 두면 수신 완료 함수에서도 같은 버퍼를 사용할 수 있습니다.
 */
static uint8_t uart2_rx_ece2;
// static uint8_t uart3_rx_ece2;

/* 여러 글자를 한 번에 받아도 놓치지 않도록 PC 수신 바이트를 모아 두는 링 버퍼(256바이트).
 * 인터럽트(uart2_isr_p6)가 넣고, 메인 루프(polling_routine)가 꺼냅니다.
 * head는 ISR만, tail은 메인 루프만 바꾸므로 8비트 인덱스 하나씩이면 충돌하지 않습니다. */
#define RX_BUF_SIZE 256U
static volatile uint8_t rx_buf[RX_BUF_SIZE];
static volatile uint8_t rx_head = 0U;   /* 다음에 넣을 위치 (ISR) */
static volatile uint8_t rx_tail = 0U;   /* 다음에 꺼낼 위치 (메인 루프) */
static volatile uint32_t rx_overflow = 0U;

/* 주변장치 초기화가 끝난 뒤, 메인 루프에 들어가기 전에 한 번 호출됩니다. */
void ece2_474_init(void)
{
    /* 필요한 기능만 주석을 해제합니다. 기본 핀·통신 설정은 이미 끝난 상태입니다.
     * VS Code에서 해당 줄에 커서를 놓거나 여러 줄을 선택하고 Ctrl + /를 누르면
     * 줄 주석(//)을 해제하거나 다시 설정할 수 있습니다.
     */

    /* TIM6: 100 ms마다 tim6_isr_p4()를 호출합니다. */
    // HAL_TIM_Base_Start_IT(&htim6);

    /* TIM3: PB4에서 1 kHz PWM을 출력합니다. 비교값 500은 50%입니다. */
    // HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_1);
    // __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_1, 500U);

    /* UART2: PC에서 한 바이트를 받으면 uart2_isr_p6()를 호출합니다.
     * 위의 uart2_rx_ece2 버퍼도 주석을 해제해야 합니다.
     * 수신 완료 함수에서 HAL_UART_Receive_IT를 다시 호출해야 다음 입력도 받습니다.
     * getchar·fgets·scanf로 같은 UART를 읽는 방식과 함께 사용하지 않습니다.
     */
    HAL_UART_Receive_IT(&huart2, &uart2_rx_ece2, 1U);   /* 과제6·7: PC 수신을 인터럽트로 */

    /* UART3: FPGA에서 한 바이트를 받으면 uart3_isr_p5()를 호출합니다.
     * 위의 uart3_rx_ece2 버퍼도 주석을 해제해야 합니다.
     * UART는 한 번 수신한 뒤, 수신 완료 함수에서 다시 수신을 요청합니다.
     */
    // HAL_UART_Receive_IT(&huart3, &uart3_rx_ece2, 1U);

    /* GPIO 입력 인터럽트는 이미 켜져 있어 별도 시작 호출이 필요 없습니다.
     * SPI·I2C와 UART 송신도 별도 시작 없이 필요한 시점에 송수신 함수를 호출합니다.
     */
}

/* 메인 루프에서 반복해서 호출됩니다. */
/* STM32_2_과제6 (여러 글자 지원): PC -> MCU -> FPGA -> PC
 * PC에서 받은 바이트를 UART2 수신 인터럽트로 링 버퍼에 모으고,
 * 메인 루프에서 하나씩 꺼내 UART3(PC10, 9600 8N1)로 FPGA에 그대로 전달합니다.
 * 20 ms 동안 새 바이트가 없으면(한 묶음 전송이 끝나면) 보낸 내용을 한 줄로 출력합니다.
 * getchar는 쓰지 않습니다(UART2 인터럽트 수신과 함께 쓰지 않음).
 */
void polling_routine(void)
{
    static char line[RX_BUF_SIZE + 1U];
    static uint32_t count = 0U;
    static uint32_t fail = 0U;
    static uint32_t last_ms = 0U;     /* 마지막으로 바이트를 꺼낸 시각 */

    if (rx_tail != rx_head)
    {
        uint8_t data = rx_buf[rx_tail];
        rx_tail = (uint8_t)(rx_tail + 1U);
        last_ms = HAL_GetTick();
        if (HAL_UART_Transmit(&huart3, &data, 1U, 100U) != HAL_OK)
        {
            fail++;
        }
        if (count < RX_BUF_SIZE)
        {
            /* 화면에 찍히지 않는 제어 문자(CR·LF 등)는 '.'로 표시 */
            line[count] = (data >= 0x20U && data <= 0x7EU) ? (char)data : '.';
            count++;
        }
    }
    else if (count > 0U && (HAL_GetTick() - last_ms) >= 20U)   /* 20 ms 동안 새 바이트 없음 = 한 묶음 끝 */
    {
        line[count] = '\0';
        printf("FPGA로 보냄: \"%s\" (%lu바이트, 전송 실패 %lu, 버퍼 넘침 %lu)\r\n",
               line, (unsigned long)count, (unsigned long)fail, (unsigned long)rx_overflow);
        count = 0U;
        fail = 0U;
    }
}

/* 1. 사용자 버튼 PC13을 눌렀을 때 호출됩니다. 우선순위: 7.
 * 버튼의 접점 때문에 한 번 눌러도 여러 번 호출될 수 있습니다.
 */
static void button_isr_p7(void)
{
    /* 실습 코드 작성: 버튼 이벤트를 기록하거나 LED 상태를 변경합니다. */
}

/* 2. TIM6를 인터럽트 방식으로 시작하면 100 ms마다 호출됩니다. 우선순위: 4.
 * 시작 호출: HAL_TIM_Base_Start_IT(&htim6);
 */
static void tim6_isr_p4(void)
{
    /* 실습 코드 작성: 횟수를 세거나 메인 루프에서 처리할 표시를 남깁니다. */
}

/* 3. PC 통신 UART2의 요청한 수신이 완료되면 호출됩니다. 우선순위: 6.
 * 먼저 수신 버퍼를 준비하고 HAL_UART_Receive_IT로 수신을 요청해야 합니다.
 * 다음 입력도 받으려면 처리 후 수신을 다시 요청합니다.
 * 현재 표준 입력은 기다리는 방식입니다. 같은 UART의 인터럽트 수신과 함께 쓰지 않습니다.
 */
static void uart2_isr_p6(void)
{
    /* 받은 1바이트를 링 버퍼에 넣고 바로 다음 수신을 요청합니다(짧게 끝냄). */
    uint8_t next = (uint8_t)(rx_head + 1U);
    if (next != rx_tail)
    {
        rx_buf[rx_head] = uart2_rx_ece2;
        rx_head = next;
    }
    else
    {
        rx_overflow++;   /* 버퍼가 가득 참: 이 바이트는 버림 */
    }
    HAL_UART_Receive_IT(&huart2, &uart2_rx_ece2, 1U);
}

/* 4. FPGA 통신 UART3의 요청한 수신이 완료되면 호출됩니다. 우선순위: 5.
 * 먼저 수신 버퍼를 준비하고 HAL_UART_Receive_IT로 수신을 요청해야 합니다.
 * 다음 입력도 받으려면 처리 후 수신을 다시 요청합니다.
 */
static void uart3_isr_p5(void)
{
    /* 실습 코드 작성: FPGA 수신 버퍼를 처리하고 다음 수신을 요청합니다. */
}

/* PA0: 풀업 입력의 HIGH -> LOW 변화. 우선순위: 8. */
static void gpio_in_pullup_isr_p8_ece2(void)
{
    /* 실습 코드 작성 */
}

/* PA1: 풀다운 입력의 LOW -> HIGH 변화. 우선순위: 9. */
static void gpio_in_pulldown_isr_p9_ece2(void)
{
    /* 실습 코드 작성 */
}

/* 아래는 HAL 콜백과 실습 함수를 연결하는 코드입니다. */

/* CubeMX의 EXTI 처리 코드에서 버튼 실습 함수로 연결합니다. */
void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin)
{
    if (GPIO_Pin == BUTTON_ece2_Pin)
    {
        button_isr_p7();
    }
    else if (GPIO_Pin == GPIO_IN_PULLUP_ece2_Pin)
    {
        gpio_in_pullup_isr_p8_ece2();
    }
    else if (GPIO_Pin == GPIO_IN_PULLDOWN_ece2_Pin)
    {
        gpio_in_pulldown_isr_p9_ece2();
    }
}

/* CubeMX의 타이머 처리 코드에서 TIM6 실습 함수로 연결합니다. */
void HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM6)
    {
        tim6_isr_p4();
    }
}

/* UART 수신 완료 시 PC 통신과 FPGA 통신을 구분합니다. */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2)
    {
        uart2_isr_p6();
    }
    else if (huart->Instance == USART3)
    {
        uart3_isr_p5();
    }
}

/* 수신 중 오버런·잡음 등 오류가 나면 HAL이 수신을 멈추므로, 여기서 다시 시작합니다. */
void HAL_UART_ErrorCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2)
    {
        HAL_UART_Receive_IT(&huart2, &uart2_rx_ece2, 1U);
    }
}
