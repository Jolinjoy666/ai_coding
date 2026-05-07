+incdir+../rtl/src
+incdir+../rtl/include
+incdir+../rtl/pkg

# RTL packages
# ../rtl/pkg/uart_pkg.sv

# Leaf modules (order matters for dependencies)
../rtl/src/baud_tick_gen.sv
../rtl/src/byte_fifo.sv
../rtl/src/crc8_stream.sv
../rtl/src/uart_rx.sv
../rtl/src/uart_tx.sv
../rtl/src/packet_parser.sv
../rtl/src/command_arbiter.sv
../rtl/src/command_engine.sv
../rtl/src/reg_file.sv
../rtl/src/memory_window.sv
../rtl/src/response_builder.sv
../rtl/src/irq_status_ctrl.sv
../rtl/src/apb_lite_slave.sv

# Top module
../rtl/src/uart_packet_controller.sv
