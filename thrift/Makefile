
OUTPUT_DIR?=lib

SRC_DIR=src
LUA_SRC=lua-5.1.5.tar.gz
LUA_DIR=lua-5.1.5
COMPAT_DIR=lua-compat-5.2

SRCS=$(wildcard $(SRC_DIR)/*.c)
OBJS=$(SRCS:%.c=%.o)

CFLAGS=-I$(LUA_DIR)/src -I$(COMPAT_DIR)/c-api \
       -L$(OUTPUT_DIR) -shared -fPIC -Wl,-E -Wl,-rpath,'$$ORIGIN'
LDFLAGS=-lm

all: $(OUTPUT_DIR) lua-src libs

clean:
	rm -f $(OUTPUT_DIR)/*.so

$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

lua-src:
	[ ! -f $(LUA_SRC) ] && wget http://www.lua.org/ftp/lua-5.1.5.tar.gz || true
	[ `md5sum $(LUA_SRC)|cut -d\  -f1` != 2e115fe26e435e33b0d5c022e4490567 ] \
		&& rm $(LUA_SRC) \
		&& wget http://www.lua.org/ftp/lua-5.1.5.tar.gz || true
	tar zxf $(LUA_SRC)

libs: \
	$(OUTPUT_DIR)/libluacompat52.so \
	$(OUTPUT_DIR)/libluabitwise.so \
	$(OUTPUT_DIR)/libluabpack.so \
	$(OUTPUT_DIR)/liblualongnumber.so \
	$(OUTPUT_DIR)/libluasocket.so

$(OUTPUT_DIR)/libluacompat52.so: $(COMPAT_DIR)/c-api/compat-5.2.c
	$(CC) $(CFLAGS) -o $@ $<

$(OUTPUT_DIR)/libluabitwise.so: $(SRC_DIR)/luabitwise.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

$(OUTPUT_DIR)/libluabpack.so: $(SRC_DIR)/luabpack.c \
				$(OUTPUT_DIR)/liblualongnumber.so
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS) -llualongnumber -lluacompat52

$(OUTPUT_DIR)/liblualongnumber.so: $(SRC_DIR)/lualongnumber.c \
				$(SRC_DIR)/longnumberutils.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OUTPUT_DIR)/libluasocket.so: $(SRC_DIR)/luasocket.c \
				$(SRC_DIR)/usocket.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

