//! account: bob, 10000GAS, 0, validator
//! account: alice, 10000GAS, 0
//! account: jim, 10000GAS, 0
//! account: lucy, 10000GAS, 0 
//! account: paul, 10000GAS, 0 
//! account: thomas, 10000GAS, 0
//! account: denice, 10000GAS, 0
//! account: carlos, 10000GAS, 0
//! account: eric, 10000GAS, 0 

// test runs various autopay pledge types to ensure they are being executed as expected

// alice commits to paying jim 5% of her worth per epoch
//! new-transaction
//! sender: alice
script {
  use 0x1::AutoPay;
  use 0x1::Signer;
  fun main(sender: &signer) {
    AutoPay::enable_autopay(sender);
    assert(AutoPay::is_enabled(Signer::address_of(sender)), 0);
    
    AutoPay::create_instruction(sender, 1, 0, {{jim}}, 2, 5);

    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction(Signer::address_of(sender), 1);
    assert(type == 0, 1);
    assert(payee == {{jim}}, 1);
    assert(end_epoch == 2, 1);
    assert(percentage == 5, 1);
  }
}
// check: EXECUTED

// lucy commits to paying paul 5% of her inflow each epoch
//! new-transaction
//! sender: lucy
script {
  use 0x1::AutoPay;
  use 0x1::Signer;
  fun main(sender: &signer) {
    AutoPay::enable_autopay(sender);
    assert(AutoPay::is_enabled(Signer::address_of(sender)), 0);
    
    AutoPay::create_instruction(sender, 1, 1, {{paul}}, 2, 5);

    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction(Signer::address_of(sender), 1);
    assert(type == 1, 1);
    assert(payee == {{paul}}, 1);
    assert(end_epoch == 2, 1);
    assert(percentage == 5, 1);
  }
}
// check: EXECUTED

// thomas commits to paying denice 200 GAS per epoch
//! new-transaction
//! sender: thomas
script {
  use 0x1::AutoPay;
  use 0x1::Signer;
  fun main(sender: &signer) {
    AutoPay::enable_autopay(sender);
    assert(AutoPay::is_enabled(Signer::address_of(sender)), 0);
    
    AutoPay::create_instruction(sender, 1, 2, {{denice}}, 2, 200);

    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction(Signer::address_of(sender), 1);
    assert(type == 2, 1);
    assert(payee == {{denice}}, 1);
    assert(end_epoch == 2, 1);
    assert(percentage == 200, 1);
  }
}
// check: EXECUTED

// carlos commits to paying eric 500 GAS at the next tick
//! new-transaction
//! sender: carlos
script {
  use 0x1::AutoPay;
  use 0x1::Signer;
  fun main(sender: &signer) {
    AutoPay::enable_autopay(sender);
    assert(AutoPay::is_enabled(Signer::address_of(sender)), 0);
    
    // note: end epoch does not matter here as long as it is after the next epoch
    AutoPay::create_instruction(sender, 1, 3, {{eric}}, 200, 500);

    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction(Signer::address_of(sender), 1);
    assert(type == 3, 1);
    assert(payee == {{eric}}, 1);
    assert(end_epoch == 200, 1);
    assert(percentage == 500, 1);
  }
}
// check: EXECUTED


///////////////////////////////////////////////////
///// Trigger Autopay Tick at 31 secs           ////
/// i.e. 1 second after 1/2 epoch  /////
//! block-prologue
//! proposer: bob
//! block-time: 31000000
//! round: 23
///////////////////////////////////////////////////


// Weird. This next block needs to be added here otherwise the prologue above does not run.
///////////////////////////////////////////////////
///// Trigger Autopay Tick at 31 secs           ////
/// i.e. 1 second after 1/2 epoch  /////
//! block-prologue
//! proposer: bob
//! block-time: 32000000
//! round: 24
///////////////////////////////////////////////////

//! new-transaction
//! sender: libraroot
script {
  use 0x1::AutoPay;
  use 0x1::LibraAccount;
  use 0x1::GAS::GAS;
  use 0x1::Libra;
  fun main(vm: &signer) {
    let ending_balance = LibraAccount::balance<GAS>({{alice}});
    assert(ending_balance == 9501, 7357004);

    // lucy didn't receive any funds, so no change in balance, so no payment sent
    let ending_balance = LibraAccount::balance<GAS>({{lucy}});
    assert(ending_balance == 10000, 7357006);

    let ending_balance = LibraAccount::balance<GAS>({{thomas}});
    assert(ending_balance == 9800, 7357006);

    let ending_balance = LibraAccount::balance<GAS>({{carlos}});
    assert(ending_balance == 9500, 7357006);
    //Confirm the one-shot pledge was deleted
    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction({{carlos}}, 1);
    assert(type == 0, 1);
    assert(payee == 0x0, 1);
    assert(end_epoch == 0, 1);
    assert(percentage == 0, 1);

    let coin = Libra::mint<GAS>(vm, 10000);
    assert(Libra::value<GAS>(&coin) == 10000, 1);
    LibraAccount::vm_deposit_with_metadata<GAS>(
        vm,
        {{lucy}},
        coin,
        x"", x""
    );

    let ending_balance = LibraAccount::balance<GAS>({{lucy}});
    assert(ending_balance == 20000, 7357006);
    
  }
}
// check: EXECUTED

///////////////////////////////////////////////////
///// Trigger Autopay Tick at 31 secs           ////
/// i.e. 1 second after 1/2 epoch  /////
//! block-prologue
//! proposer: bob
//! block-time: 61000000
//! round: 65
///////////////////////////////////////////////////

///////////////////////////////////////////////////
///// Trigger Autopay Tick at 31 secs           ////
/// i.e. 1 second after 1/2 epoch  /////
//! block-prologue
//! proposer: bob
//! block-time: 92000000
//! round: 66
///////////////////////////////////////////////////
///////////////////////////////////////////////////
///// Trigger Autopay Tick at 31 secs           ////
/// i.e. 1 second after 1/2 epoch  /////
//! block-prologue
//! proposer: bob
//! block-time: 93000000
//! round: 67
///////////////////////////////////////////////////

//! new-transaction
//! sender: libraroot
script {
  use 0x1::LibraAccount;
  use 0x1::GAS::GAS;
  use 0x1::AutoPay;
  fun main(_vm: &signer) {
    let ending_balance = LibraAccount::balance<GAS>({{alice}});
    assert(ending_balance == 9026, 7357004);

    // lucy will have paid 5% on the 10000 she received last epoch
    let ending_balance = LibraAccount::balance<GAS>({{lucy}});
    assert(ending_balance == 19501, 7357006);
    
    let ending_balance = LibraAccount::balance<GAS>({{thomas}});
    assert(ending_balance == 9600, 7357006);

    // no change, one-shot pledge is finished
    let ending_balance = LibraAccount::balance<GAS>({{carlos}});
    assert(ending_balance == 9500, 7357006);

    // check balance of recipients
    let ending_balance = LibraAccount::balance<GAS>({{jim}});
    assert(ending_balance == 10974, 7357006);

    let ending_balance = LibraAccount::balance<GAS>({{paul}});
    assert(ending_balance == 10499, 7357006);

    let ending_balance = LibraAccount::balance<GAS>({{denice}});
    assert(ending_balance == 10400, 7357006);

    let ending_balance = LibraAccount::balance<GAS>({{eric}});
    assert(ending_balance == 10500, 7357006);

    //all pledges should be deleted as they expired in epoch 2, check to confirm
    //Confirm the one-shot pledge was deleted
    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction({{alice}}, 1);
    assert(type == 0, 1);
    assert(payee == 0x0, 1);
    assert(end_epoch == 0, 1);
    assert(percentage == 0, 1);

    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction({{lucy}}, 1);
    assert(type == 0, 1);
    assert(payee == 0x0, 1);
    assert(end_epoch == 0, 1);
    assert(percentage == 0, 1);

    let (type, payee, end_epoch, percentage) = AutoPay::query_instruction({{thomas}}, 1);
    assert(type == 0, 1);
    assert(payee == 0x0, 1);
    assert(end_epoch == 0, 1);
    assert(percentage == 0, 1);
  }


}
// check: EXECUTED
