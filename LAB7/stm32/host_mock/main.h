/* PC 모의 실행용 가짜 main.h (LAB7 · SPI 추가)
 * 수업 ece2_474_routine.c(과제 코드)를 한 글자도 바꾸지 않고 gcc로 컴파일하기 위한 최소 정의.
 * 값(상수)은 STM32G4 HAL과 같은 이름만 맞추고, 실제 숫자는 이 모의 실행 안에서만 의미가 있다. */
#ifndef MOCK_MAIN_H
#define MOCK_MAIN_H
#include <stdint.h>
#include <stdio.h>
typedef enum { HAL_OK = 0, HAL_ERROR = 1, HAL_BUSY = 2, HAL_TIMEOUT = 3 } HAL_StatusTypeDef;
typedef struct { int id; } PERIPH_TypeDef;
typedef struct { int id; } GPIO_TypeDef;
typedef struct { PERIPH_TypeDef *Instance; } TIM_HandleTypeDef;
typedef struct { PERIPH_TypeDef *Instance; } UART_HandleTypeDef;
typedef struct { PERIPH_TypeDef *Instance; } I2C_HandleTypeDef;

/* SPI: 매뉴얼 코드가 건드리는 Init 항목 + main.c MX_SPI1_Init이 정하는 항목 */
typedef struct {
    uint32_t Mode, Direction, DataSize, CLKPolarity, CLKPhase, NSS, BaudRatePrescaler, FirstBit;
} SPI_InitTypeDef;
typedef struct { PERIPH_TypeDef *Instance; SPI_InitTypeDef Init; int initialized; } SPI_HandleTypeDef;
#define SPI_MODE_SLAVE            0U
#define SPI_MODE_MASTER           1U
#define SPI_DIRECTION_2LINES      0U
#define SPI_DATASIZE_8BIT         8U
#define SPI_POLARITY_LOW          0U
#define SPI_PHASE_1EDGE           0U
#define SPI_NSS_SOFT              1U
#define SPI_NSS_HARD_INPUT        2U
#define SPI_BAUDRATEPRESCALER_128 128U
#define SPI_FIRSTBIT_MSB          0U

/* GPIO */
typedef enum { GPIO_PIN_RESET = 0, GPIO_PIN_SET = 1 } GPIO_PinState;
typedef struct { uint32_t Pin, Mode, Pull, Speed, Alternate; } GPIO_InitTypeDef;
extern GPIO_TypeDef mock_gpioa, mock_gpiob, mock_gpioc;
#define GPIOA (&mock_gpioa)
#define GPIOB (&mock_gpiob)
#define GPIOC (&mock_gpioc)
#define GPIO_PIN_4   0x0010U
#define GPIO_PIN_6   0x0040U
#define GPIO_MODE_AF_PP        2U
#define GPIO_PULLUP            1U
#define GPIO_SPEED_FREQ_LOW    0U
#define GPIO_AF5_SPI1          5U
#define SPI_CS_ece2_Pin        GPIO_PIN_6       /* main.h: PB6 */
#define SPI_CS_ece2_GPIO_Port  GPIOB

extern PERIPH_TypeDef mock_tim6, mock_usart2, mock_usart3, mock_spi1;
#define TIM6   (&mock_tim6)
#define USART2 (&mock_usart2)
#define USART3 (&mock_usart3)
#define SPI1   (&mock_spi1)
#define BUTTON_ece2_Pin            0x2000U
#define GPIO_IN_PULLUP_ece2_Pin    0x0001U
#define GPIO_IN_PULLDOWN_ece2_Pin  0x0002U

uint32_t HAL_GetTick(void);
void Error_Handler(void);
void HAL_GPIO_WritePin(GPIO_TypeDef *port, uint16_t pin, GPIO_PinState s);
void HAL_GPIO_Init(GPIO_TypeDef *port, GPIO_InitTypeDef *init);
HAL_StatusTypeDef HAL_SPI_Init(SPI_HandleTypeDef *h);
HAL_StatusTypeDef HAL_SPI_DeInit(SPI_HandleTypeDef *h);
HAL_StatusTypeDef HAL_SPI_Transmit(SPI_HandleTypeDef *h, const uint8_t *p, uint16_t n, uint32_t t);
HAL_StatusTypeDef HAL_SPI_Receive(SPI_HandleTypeDef *h, uint8_t *p, uint16_t n, uint32_t t);
HAL_StatusTypeDef HAL_TIM_Base_Start_IT(TIM_HandleTypeDef *h);
HAL_StatusTypeDef HAL_UART_Receive_IT(UART_HandleTypeDef *h, uint8_t *p, uint16_t n);
HAL_StatusTypeDef HAL_UART_Transmit(UART_HandleTypeDef *h, const uint8_t *p, uint16_t n, uint32_t t);
#endif
