/* PC 모의 실행용 가짜 main.h: 수업 ece2_474_routine.c를 한 글자도 바꾸지 않고 gcc로 컴파일하기 위한 최소 정의 */
#ifndef MOCK_MAIN_H
#define MOCK_MAIN_H
#include <stdint.h>
#include <stdio.h>
typedef enum { HAL_OK = 0, HAL_ERROR = 1, HAL_BUSY = 2, HAL_TIMEOUT = 3 } HAL_StatusTypeDef;
typedef struct { int id; } PERIPH_TypeDef;
typedef struct { PERIPH_TypeDef *Instance; } TIM_HandleTypeDef;
typedef struct { PERIPH_TypeDef *Instance; } UART_HandleTypeDef;
typedef struct { PERIPH_TypeDef *Instance; } SPI_HandleTypeDef;
typedef struct { PERIPH_TypeDef *Instance; } I2C_HandleTypeDef;
extern PERIPH_TypeDef mock_tim6, mock_usart2, mock_usart3;
#define TIM6   (&mock_tim6)
#define USART2 (&mock_usart2)
#define USART3 (&mock_usart3)
#define BUTTON_ece2_Pin            0x2000U
#define GPIO_IN_PULLUP_ece2_Pin    0x0001U
#define GPIO_IN_PULLDOWN_ece2_Pin  0x0002U
HAL_StatusTypeDef HAL_UART_Transmit(UART_HandleTypeDef *h, const uint8_t *p, uint16_t n, uint32_t t);
#endif
