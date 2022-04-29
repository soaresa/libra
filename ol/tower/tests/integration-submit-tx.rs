
#![forbid(unsafe_code)]

use std::{fs, path::{Path}, process::{Command, Stdio}, thread, time::{self, Duration}};
use diem_config::config::NodeConfig;
use ol::config::AppCfg;
use txs::tx_params::TxParams;
use anyhow::{bail, Error};

#[test]
#[ignore]
/// In case the miner fails to connect with client, miner should continue mining 
/// and submit the backlog on each block. This test simulates this issue by blocking 
/// the port in between and testing the connectivity. 
pub fn integration_submit_tx() {
    
    // the miner needs to start producing proof_1.json. If proof_1.json is not successful, then block_2 cannot be either, because it depends on certain on-chain state from block_1 correct submission.
    let miner_source_path = Path::new(env!("CARGO_MANIFEST_DIR"));
    let root_source_path = miner_source_path.parent().unwrap().parent().unwrap();
    let home = dirs::home_dir().unwrap();
    let swarm_configs_path = home.join(".0L/swarm_temp/");

    match fs::remove_dir_all(&swarm_configs_path) {
        Ok(_) => { println!("wiping swarm temp directory! {:?}", &swarm_configs_path)},
        Err(_) => {},
    }

    let node_exec = &root_source_path.join("target/debug/diem-node");
    // TODO: Assert that proof_0.json is in blocks folder.
    std::env::set_var("RUST_LOG", "debug");
    let mut swarm_cmd = Command::new("cargo");
    swarm_cmd.current_dir(&root_source_path.as_os_str());
    swarm_cmd.env("NODE_ENV", "test")
            .arg("run")
            .arg("-p").arg("diem-swarm")
            .arg("--")
            .arg("-n").arg("1")
            .arg("--diem-node").arg(node_exec.to_str().unwrap())
            .arg("-c").arg(swarm_configs_path.to_str().unwrap());
    let cmd = swarm_cmd.stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .spawn();
    match cmd {
        // Swarm has started
        Ok(mut swarm_child) => {
            // need to wait for swarm to start-up before we have the configs needed to connect to it. Check stdout.
            block_until_swarm_ready();
            println!("READY!");
            // wait a bit more, because the previous command only checks for config fils creation.
            let test_timeout = Duration::from_secs(30);
            thread::sleep(test_timeout);

                        // start the miner swarm test helper.
            let mut init_cmd = Command::new("cargo");
            init_cmd.arg("run")
                    .arg("-p")
                    .arg("ol")
                    .arg("--")
                    .arg("--swarm-path")
                    .arg(swarm_configs_path.to_str().unwrap())
                    .arg("--swarm-persona")
                    .arg("alice")
                    .arg("init")
                    .arg("--source-path")
                    .arg(root_source_path.to_str().unwrap());
            let mut init_child = init_cmd.stdout(Stdio::inherit())
                    .stderr(Stdio::inherit())
                    .spawn()
                    .unwrap();
            init_child.wait().unwrap();

            // start the miner swarm test helper.
            let mut miner_cmd = Command::new("cargo");
            miner_cmd.env("NODE_ENV", "test")
                    .arg("run")
                    .arg("-p")
                    .arg("miner")
                    .arg("--")
                    .arg("--swarm-path")
                    .arg(swarm_configs_path.to_str().unwrap())
                    .arg("--swarm-persona")
                    .arg("alice")
                    .arg("start");
            let mut miner_child = miner_cmd.stdout(Stdio::inherit())
                    .stderr(Stdio::inherit())
                    .spawn()
                    .unwrap();

            // TODO: need to parse output of the stdio

            // set a timeout. Let the node run for sometime. 
            let test_timeout = Duration::from_secs(30);
            thread::sleep(test_timeout);

            // TODO: make these paths references
            let tx_params = TxParams::get_tx_params_from_swarm(swarm_configs_path.clone(), "alice".to_owned(), false).unwrap();// TO write logic
            let config =  AppCfg::init_app_configs_swarm(swarm_configs_path.clone(), 
                                    swarm_configs_path.join("0"), Some(root_source_path.clone().to_path_buf())).unwrap();

            let mut blocks_dir = config.workspace.node_home.clone();
            blocks_dir.push(&config.workspace.block_dir);


            let (current_block_number, _current_block_path) = tower::proof::parse_block_height(&blocks_dir);
            let block_number_before_block = current_block_number.unwrap();
            

            println!("Check node sync before disabling port");
            match check_node_sync(&tx_params, &config) {
                Ok(()) => {},
                Err(err) => {
                    swarm_child.kill().unwrap();
                    miner_child.kill().unwrap();
                    std::panic!("Check node sync failed: {}", err)
                }
            };
                
            let port = get_node_port(); // node port

            // Block the port
            println!("Blocking the port: {}", port);
            let mut block_port_cmd = Command::new("sudo");
            block_port_cmd.arg("iptables").arg("-A").arg("OUTPUT").arg("-p")
                .arg("tcp").arg("--match").arg("multiport").arg("--dports")
                .arg(port.to_string()).arg("-j").arg("DROP");
            block_port_cmd.stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .spawn()
                .unwrap();
            
            

            // let miner mine without submitting
            let test_timeout = Duration::from_secs(240); // To let the timeout happen and continue mining. 
            thread::sleep(test_timeout);
            
            let (current_block_number, _current_block_path) = tower::proof::parse_block_height(&blocks_dir);
            let block_number_after_unblock = current_block_number.unwrap();
            
            // Miner should have continued mining. +1 to consider atleast 2 blocks mined. 
            if block_number_after_unblock <= (block_number_before_block + 1) {
                std::panic!("Miner did not mine during port block: Blocks Before block: {}, blocks after unblock: {}", block_number_before_block, block_number_after_unblock);
            }

            // activate the port
            println!("Reactivate the port: {}", port);
            let mut activate_port_cmd = Command::new("sudo");
            activate_port_cmd.arg("iptables").arg("-D").arg("OUTPUT").arg("-p")
                .arg("tcp").arg("--match").arg("multiport").arg("--dports")
                .arg(port.to_string()).arg("-j").arg("DROP");
            activate_port_cmd.stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .spawn()
                .unwrap();
            
            // let miner submit the backlog
            let test_timeout = Duration::from_secs(120); // enough time to submit back log
            thread::sleep(test_timeout);
            println!("Check node sync after disabling port");
            match check_node_sync(&tx_params, &config) {
                Ok(()) => {},
                Err(err) => {
                    swarm_child.kill().unwrap();
                    miner_child.kill().unwrap();
                    std::panic!("Check node sync failed after block & re-active port: {}", err)
                }
            };

            swarm_child.kill().unwrap();
            miner_child.kill().unwrap();
            
        }
        Err(err) => println!("Swarm child process did not start: {}", err)
    }
}

fn block_until_swarm_ready() -> bool {
    let home = dirs::home_dir().unwrap();
    let swarm_configs_path = home.join("swarm_temp/");
    let mut timeout = 100;
    let one_second = time::Duration::from_secs(1);

    loop {
        if timeout == 0 { 
            return false
        }
        if swarm_configs_path.exists() {
            return true
        }

        thread::sleep(one_second);
        timeout -= 1;
    }
}

fn get_node_port() -> u16 {
    let home = dirs::home_dir().unwrap();
    let swarm_configs_path = home.join(".0L/swarm_temp/");
    
    let yaml_path = swarm_configs_path.join("0/node.yaml");
    let node_conf = NodeConfig::load(&yaml_path).unwrap();

    node_conf.json_rpc.address.port()
}

fn check_node_sync(tx_params: &TxParams, config: &AppCfg) -> Result<(), Error> {
    let (remote_height, _) = tower::backlog::get_remote_tower_height(&tx_params).unwrap();
    println!("Remote tower height: {}", remote_height);

    let mut blocks_dir = config.workspace.node_home.clone();
    blocks_dir.push(&config.workspace.block_dir);
    let (current_block_number, _current_block_path) = tower::proof::parse_block_height(&blocks_dir);
    let current_block_number = current_block_number.unwrap() as i64;
    println!("Local tower height: {}", current_block_number);

    // The client can be in sync with local or -1 wrt local. 
    if (current_block_number != remote_height) && (current_block_number - 1) != remote_height {
        bail!("Block heights don't match: Miner: {}, Remote: {}", current_block_number, remote_height)
    }
    Ok(())
}
