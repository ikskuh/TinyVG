#ifndef TINYVG_HEADER_GUARD
#define TINYVG_HEADER_GUARD

#include <stddef.h>
#include <stdint.h>

enum tinyvg_Error
{
  TINYVG_SUCCESS = 0,
  TINYVG_ERR_OUT_OF_MEMORY = 1,
  TINYVG_ERR_IO = 2,
  TINYVG_ERR_INVALID_DATA = 3,
  TINYVG_ERR_UNSUPPORTED = 4,
};

enum tinyvg_AntiAlias
{
  TINYVG_AA_NONE = 1,
  TINYVG_AA_X4 = 2,
  TINYVG_AA_X9 = 3,
  TINYVG_AA_x16 = 4,
  TINYVG_AA_x25 = 6,
  TINYVG_AA_x49 = 7,
  TINYVG_AA_x64 = 8,
};

struct tinyvg_OutStream
{
  void * context;
  enum tinyvg_Error (*write)(void * context, uint8_t const * buffer, size_t length, size_t * written);
};

struct tinyvg_Bitmap
{
  uint32_t width;
  uint32_t height;
  uint8_t * pixels;
};

enum tinyvg_Error tinyvg_render_svg(
  uint8_t const * tvg_data,
  size_t tvg_length,
  struct tinyvg_OutStream const * target
);

enum tinyvg_Error tinyvg_render_bitmap(
  uint8_t const * tvg_data,
  size_t tvg_length,
  enum tinyvg_AntiAlias anti_alias,
  uint32_t width,
  uint32_t height,
  struct tinyvg_Bitmap * bitmap
);

void tinyvg_free_bitmap(struct tinyvg_Bitmap * bitmap);

#ifndef TINYVG_NO_EXPORT_TYPES
typedef enum tinyvg_Error tinyvg_Error;
typedef enum tinyvg_AntiAlias tinyvg_AntiAlias;
typedef struct tinyvg_OutStream tinyvg_OutStream;
typedef struct tinyvg_Bitmap tinyvg_Bitmap;
#endif

#endif 
