# 编译参数
CC := gcc
CXX := g++
AR := ar
RANLIB := ranlib
SHARE := -fpic -shared -o
INCLUDE := -I./ \
	-I/usr/include/ \
	-I/usr/local/include/
LIBS := -L./ \
	-L/usr/lib/ \
	-L/usr/lib32/ \
	-L/usr/local/lib/
LDFLAGS := libleveldb.a -lpthread -lsnappy
DEFINES := 
CFLAGS := -g -Wall -O2 $(INCLUDE) $(DEFINES)
CXXFLAGS := -std=c++11 $(CFLAGS) -DHAVE_CONFIG_H

# make工具, Makefile指定.
MAKE = make
MAKEFILE = Makefile

# 文件扩展名相关.
SRCEXT = .c .cc .cpp .cxx .c++
# func: get suffix, match them in SRCEXT.
# arg: srcs.
get_suffix = $(filter $(suffix $(1)),$(SRCEXT))

# func: get suffix and suffix must be only one.
# arg: srcs, ret_suffix.
# none is not regular suffix.
#define suffix_uniq
#    suf_arr := $(call get_suffix, $(1))
#    suf_cnt := $(words $(suf_arr))
#    ifeq ($(suf_cnt),1)
#        $(2) := $(suf_arr)
#    endif
#    undefine suf_arr
#    undefine suf_cnt
#endef

# this func is useful.
# arg: srcs, varsuffix.
define suffix_uniq
	ifeq ($(words $(call get_suffix,$(SRCS_$(1)))),1)
		SUFFIX_$(1) := $(call get_suffix,$(SRCS_$(1)))
	else
		SUFFIX_$(1) := fuck
	endif
	ifneq ($(SUFFIX_$(1)),fuck)
		ifeq ($(SUFFIX_$(1)),.c)
			CC_$(1) := $(CC)
		else
			CC_$(1) := $(CXX)
		endif
	endif
endef

# func: get compiler is gcc or g++.
# arg: src, suffix, compiler.
define init_compiler
	$(eval $(call suffix_uniq, $(1), $(2)))
	ifeq ($(2), .c)
		$(3) := $(CC)
	endif
	ifeq ($(2), .cpp)
		$(3) := $(CXX)
	endif
endef

# default target
default: all

# 这块自行修改.
# 所有目标, 填数字即可, 对应aim_$<.
aimid_all = 1
.PHONY: aim_all
aim_all: init_1
	@echo "in "$@
#	@for id in $(aimid_all);
	@echo "SUFFIX_1 is $(SUFFIX_1)"
	@echo "CC_1 is $(CC_1)"
	@echo "OBJS_1 IS $(OBJS_1)"
	@echo "out "$@
# 自定义文件, 支持多个目标, 写好每个目标的源文件名和目标文件名.
# 有编译可执行文件, 静态链接库, 动态链接库.
#aim_1 ?= $(call gen_temp) #写在这里会每次都生成一下随机名字, 导致找不到目标.
EXE_1:= ttt
STATIC_1 := 
DYNAMIC_1 := 
ALL_1 := $(EXE_1) $(STATIC_1) $(DYNAMIC_1)
SRCS_1 := c_shell.cpp dsm_db.cpp
# 具体编译过程, 这里可能会把其他目标的OBJS一起编译进来.
# LDFLAGS仅在链接时使用.
$(EXE_1): $(OBJS_1)
	@echo "in $@"
	@echo "ALL_1 IS $(ALL_1)"
	@echo "CC_1 is $(CC_1)"
	@echo "SUFFIX_1 is $(SUFFIX_1)"
	@echo "OBJS_1 IS $(OBJS_1)"
	$(CC_1) -o$@ $^ $(LIBS) $(LDFLAGS)
	@echo "out $@"
$(STATIC_1): $(OBJS_1)
	$(AR) crs $@ $^
	$(RANLIB) $@
$(DYNAMIC_1): $(OBJS_1)
	$(CC_1) $(SHARE) $@ $^ $(LDFLAGS) $(LIBS)
# 需要按照源文件类型获得后缀和编译器类型.
.PHONY: init_1
init_1:
	@echo "in $@"
#	@$(eval $(call init_compiler, $(SRCS_1), SUFFIX_1, CC_1))
#	this call not use(origin version).
#	$(eval $(call suffix_uniq, $(SRCS_1), SUFFIX_1))
	$(eval $(call suffix_uniq,1))
	@echo "SUFFIX_1 is $(SUFFIX_1)"
	@echo "CC_1 is $(CC_1)"
	$(eval OBJS_1 = $(SRCS_1:$(SUFFIX_1)=.o))
	@echo "OBJS_1 IS $(OBJS_1)"
	$(eval sinclude $(OBJS_1:.o=.d))
	$(eval TARGET += $(ALL_1))
	$(eval export SUFFIX_1 CC_1 OBJS_1)
	make $(ALL_1)
	@echo "out $@"
# 所有目标合集, 多目标的话把所有需要的都放到这里.
TARGET :=

# 以下一般不需要改
.PHONY: all
all: aim_all
	@echo "in $@"
	@echo "TARGET IS $(TARGET)"
	@echo "out $@"
.PHONY: clean
clean:
	rm -f *.orig *~ *.o *.d
cleanall: clean
	rm -f $(TARGET)

# 约定俗成的根据源文件自动生成头文件依赖.
# func: get dependence rule file.
# arg: src, dep_file, compiler.
# src file like .c .cpp ...
# dependence rule file like .d .o: .c(pp) .h(pp) ...
define mkdep
	@set -e
	@rm -f $(2)
	@$(3) -MM $(1) | awk '{print "$(2)", $$0}' > $(2)
endef
%.d: %.c
	@$(call mkdep,$<,$@,$(CC))

%.d: %.cpp
	@$(call mkdep,$<,$@,$(CXX))

# 以下是生成.d文件的4种方法.
# 形如%.d %.o: %.c something.h...
# 生成.d的原因是.h里面增加或减少包含其他.h文件, .d也能同步更新.
#@$(CC) -MM $< | awk '{print "$@", $$0}' > $@
#@$(CC) -MM $< | awk '{printf "%s %s\n", "$@", $$0}' > $@
#@$(CC) -MM $< | sed 's:^\(.*\):$@ \1:g' > $@
#@$(CC) -MM $(CPPFLAGS) $< > $@.$$$$; \
#	sed 's,\($*\)\.o[ :]*,\1.o $@: ,g' < $@.$$$$ > $@; \
#	rm -f $@.$$$$
