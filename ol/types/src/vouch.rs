//! vouch view for web monitor

use diem_types::{
  access_path::AccessPath,
  account_config::constants:: CORE_CODE_ADDRESS,
};
use anyhow::Result;
use move_core_types::{
  ident_str,
  identifier::IdentStr,
  language_storage::{ResourceKey, StructTag},
  move_resource::{MoveResource, MoveStructType},
};
use serde::{Deserialize, Serialize};
use move_core_types::account_address::AccountAddress;

/// Struct that represents a Vouch resource
#[derive(Debug, Serialize, Deserialize)]
pub struct VouchResource {
  ///
  pub vals: Vec<AccountAddress>,
}

/// Struct that represents a view for an account vouched
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountVouchedView {
  ///
  pub address: AccountAddress,
  ///
  pub note: Option<String>
}

/// Struct that represents a view for Vouch resource
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VouchView {
  ///
  pub received: Vec<AccountVouchedView>,
}

impl MoveStructType for VouchResource {
  const MODULE_NAME: &'static IdentStr = ident_str!("Vouch");
  const STRUCT_NAME: &'static IdentStr = ident_str!("Vouch");
}
impl MoveResource for VouchResource {}

impl VouchResource {
  ///
  pub fn struct_tag() -> StructTag {
    StructTag {
      address: CORE_CODE_ADDRESS,
      module: VouchResource::module_identifier(),
      name: VouchResource::struct_identifier(),
      type_params: vec![],
    }
  }
  ///
  pub fn access_path(account: AccountAddress) -> AccessPath {
    let resource_key = ResourceKey::new(
      account,
      VouchResource::struct_tag(),
    );
    AccessPath::resource_access_path(resource_key)
  }
  ///
  pub fn resource_path() -> Vec<u8> {
    AccessPath::resource_access_vec(VouchResource::struct_tag())
  }

  /// 
  pub fn try_from_bytes(bytes: &[u8]) -> Result<Self> {
    bcs::from_bytes(bytes).map_err(Into::into)
  }

  ///
  pub fn get_view(&self) -> VouchView {
    VouchView { 
      received: self.vals
        .iter()
        .map(|address| AccountVouchedView {
          address: address.clone(),
          note: None
        })
        .collect()
    }
  }
}
