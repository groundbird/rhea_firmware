# The first flip-flop in each reset synchronizer intentionally receives an
# asynchronous assertion/deassertion. Its second stage provides synchronous
# reset release to the corresponding clock domain.
set reset_sync_async_pins [get_pins -hier -regexp {.*reset_pipe_reg\[[01]\]/PRE}]
set_false_path -to $reset_sync_async_pins
