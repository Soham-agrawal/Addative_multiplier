SIM ?= icarus
TOPLEVEL_LANG ?= verilog
export PYTHONPATH := $(PWD)/testbench:$(PYTHONPATH)


VERILOG_SOURCES += $(PWD)/verilog/multiplier_unified.v
COCOTB_TOPLEVEL = multiplier_unified
COCOTB_TEST_MODULES = test_multiplier_unified

include $(shell cocotb-config --makefiles)/Makefile.sim
#open in terminal and run the following commands to run the testbench
#conda activate cocotb_env
#python -c "import cocotb; print(cocotb.__version__)"
#make