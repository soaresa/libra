
<a name="0x1_Epoch"></a>

# Module `0x1::Epoch`


<a name="@Summary_0"></a>

## Summary

This module allows the root to determine epoch boundaries, triggering
epoch change operations (e.g. updating the validator set)


-  [Summary](#@Summary_0)
-  [Resource `Timer`](#0x1_Epoch_Timer)
-  [Function `initialize`](#0x1_Epoch_initialize)
-  [Function `epoch_finished`](#0x1_Epoch_epoch_finished)
-  [Function `reset_timer`](#0x1_Epoch_reset_timer)
-  [Function `get_timer_seconds_start`](#0x1_Epoch_get_timer_seconds_start)
-  [Function `get_timer_height_start`](#0x1_Epoch_get_timer_height_start)


<pre><code><b>use</b> <a href="CoreAddresses.md#0x1_CoreAddresses">0x1::CoreAddresses</a>;
<b>use</b> <a href="DiemConfig.md#0x1_DiemConfig">0x1::DiemConfig</a>;
<b>use</b> <a href="DiemTimestamp.md#0x1_DiemTimestamp">0x1::DiemTimestamp</a>;
<b>use</b> <a href="Globals.md#0x1_Globals">0x1::Globals</a>;
<b>use</b> <a href="Roles.md#0x1_Roles">0x1::Roles</a>;
</code></pre>



<a name="0x1_Epoch_Timer"></a>

## Resource `Timer`

Contains timing info for the current epoch
epoch: the epoch number
height_start: the block height the epoch started at
seconds_start: the start time of the epoch


<pre><code><b>struct</b> <a href="Epoch.md#0x1_Epoch_Timer">Timer</a> has key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>height_start: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>seconds_start: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x1_Epoch_initialize"></a>

## Function `initialize`

Called in genesis to initialize timer


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_initialize">initialize</a>(vm: &signer)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_initialize">initialize</a>(vm: &signer) {
    <a href="Roles.md#0x1_Roles_assert_diem_root">Roles::assert_diem_root</a>(vm);
    move_to&lt;<a href="Epoch.md#0x1_Epoch_Timer">Timer</a>&gt;(
        vm,
        <a href="Epoch.md#0x1_Epoch_Timer">Timer</a> {
            epoch: 0,
            height_start: 0,
            seconds_start: <a href="DiemTimestamp.md#0x1_DiemTimestamp_now_seconds">DiemTimestamp::now_seconds</a>()
        }
    );
}
</code></pre>



</details>

<a name="0x1_Epoch_epoch_finished"></a>

## Function `epoch_finished`

Check to see if epoch is finished
Simply checks if the elapsed time is greater than the epoch time


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_epoch_finished">epoch_finished</a>(height_now: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_epoch_finished">epoch_finished</a>(height_now: u64): bool <b>acquires</b> <a href="Epoch.md#0x1_Epoch_Timer">Timer</a> {
    <b>let</b> time = borrow_global&lt;<a href="Epoch.md#0x1_Epoch_Timer">Timer</a>&gt;(<a href="CoreAddresses.md#0x1_CoreAddresses_DIEM_ROOT_ADDRESS">CoreAddresses::DIEM_ROOT_ADDRESS</a>());

    // we target 24hrs for block production.
    // there are failure cases when there is a halt, and nodes have been offline for all of the 24hrs, producing a new epoch upon restart leads <b>to</b> further failures. So we check that a meaninful amount of blocks have been created too.

    <b>let</b> enough_blocks = height_now &gt; (time.height_start + <a href="Globals.md#0x1_Globals_get_min_blocks_epoch">Globals::get_min_blocks_epoch</a>());

    <b>let</b> time_now = <a href="DiemTimestamp.md#0x1_DiemTimestamp_now_seconds">DiemTimestamp::now_seconds</a>();
    <b>let</b> len = <a href="Globals.md#0x1_Globals_get_epoch_length">Globals::get_epoch_length</a>();
    <b>let</b> enough_time = (time_now &gt; (time.seconds_start + len));

    (enough_blocks && enough_time)

}
</code></pre>



</details>

<a name="0x1_Epoch_reset_timer"></a>

## Function `reset_timer`

Reset the timer to start the next epoch
Called by root in the reconfiguration process


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_reset_timer">reset_timer</a>(vm: &signer, height: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_reset_timer">reset_timer</a>(vm: &signer, height: u64) <b>acquires</b> <a href="Epoch.md#0x1_Epoch_Timer">Timer</a> {
    <a href="Roles.md#0x1_Roles_assert_diem_root">Roles::assert_diem_root</a>(vm);
    <b>let</b> time = borrow_global_mut&lt;<a href="Epoch.md#0x1_Epoch_Timer">Timer</a>&gt;(<a href="CoreAddresses.md#0x1_CoreAddresses_DIEM_ROOT_ADDRESS">CoreAddresses::DIEM_ROOT_ADDRESS</a>());
    time.epoch = <a href="DiemConfig.md#0x1_DiemConfig_get_current_epoch">DiemConfig::get_current_epoch</a>() + 1;
    time.height_start = height;
    time.seconds_start = <a href="DiemTimestamp.md#0x1_DiemTimestamp_now_seconds">DiemTimestamp::now_seconds</a>();
}
</code></pre>



</details>

<a name="0x1_Epoch_get_timer_seconds_start"></a>

## Function `get_timer_seconds_start`

Accessor Function, returns the time (in seconds) of the start of the current epoch


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_get_timer_seconds_start">get_timer_seconds_start</a>(vm: &signer): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_get_timer_seconds_start">get_timer_seconds_start</a>(vm: &signer):u64 <b>acquires</b> <a href="Epoch.md#0x1_Epoch_Timer">Timer</a> {
    <a href="Roles.md#0x1_Roles_assert_diem_root">Roles::assert_diem_root</a>(vm);
    <b>let</b> time = borrow_global&lt;<a href="Epoch.md#0x1_Epoch_Timer">Timer</a>&gt;(<a href="CoreAddresses.md#0x1_CoreAddresses_DIEM_ROOT_ADDRESS">CoreAddresses::DIEM_ROOT_ADDRESS</a>());
    time.seconds_start
}
</code></pre>



</details>

<a name="0x1_Epoch_get_timer_height_start"></a>

## Function `get_timer_height_start`

Accessor Function, returns the block height of the start of the current epoch


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_get_timer_height_start">get_timer_height_start</a>(vm: &signer): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="Epoch.md#0x1_Epoch_get_timer_height_start">get_timer_height_start</a>(vm: &signer):u64 <b>acquires</b> <a href="Epoch.md#0x1_Epoch_Timer">Timer</a> {
    <a href="Roles.md#0x1_Roles_assert_diem_root">Roles::assert_diem_root</a>(vm);
    <b>let</b> time = borrow_global&lt;<a href="Epoch.md#0x1_Epoch_Timer">Timer</a>&gt;(<a href="CoreAddresses.md#0x1_CoreAddresses_DIEM_ROOT_ADDRESS">CoreAddresses::DIEM_ROOT_ADDRESS</a>());
    time.height_start
}
</code></pre>



</details>


[//]: # ("File containing references which can be used from documentation")
[ACCESS_CONTROL]: https://github.com/diem/dip/blob/main/dips/dip-2.md
[ROLE]: https://github.com/diem/dip/blob/main/dips/dip-2.md#roles
[PERMISSION]: https://github.com/diem/dip/blob/main/dips/dip-2.md#permissions
