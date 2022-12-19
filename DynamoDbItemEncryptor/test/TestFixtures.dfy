// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
include "../src/Index.dfy"

module TestFixtures {
  import opened Wrappers
  import opened StandardLibrary
  import opened UInt = StandardLibrary.UInt
  import AwsCryptographyMaterialProvidersTypes
  import MaterialProviders
  import Types = AwsCryptographyDynamoDbItemEncryptorTypes
  import DynamoDbItemEncryptor
  import CTypes = AwsCryptographyStructuredEncryptionTypes

  //const EXPECTED_STUBBED_BLOB : seq<uint8> := [0x21, 0x64, 0x6c, 0x72, 0x6f, 0x77, 0x20, 0x2c, 0x6f, 0x6c, 0x6c, 0x65, 0x68];

  method GetStaticKeyring()
      returns (keyring: AwsCryptographyMaterialProvidersTypes.IKeyring)
    ensures keyring.ValidState()
    ensures fresh(keyring)
    ensures fresh(keyring.Modifies)
  {
    var matProv :- expect MaterialProviders.MaterialProviders();
    keyring :- expect matProv.CreateRawAesKeyring(
      AwsCryptographyMaterialProvidersTypes.CreateRawAesKeyringInput(
        keyNamespace := "foo",
        keyName := "bar",
        wrappingKey := seq(32, i => 0),
        wrappingAlg := AwsCryptographyMaterialProvidersTypes.ALG_AES256_GCM_IV12_TAG16
      )
    );
  }

  function method GetAttributeActions() : Types.AttributeActions {
    map["bar" := CTypes.SIGN_ONLY, "encrypt" := CTypes.ENCRYPT_AND_SIGN, "sign" := CTypes.SIGN_ONLY, "nothing" := CTypes.DO_NOTHING]
  }


  method GetEncryptorConfig() returns (output : Types.DynamoDbItemEncryptorConfig) {
    var keyring := GetStaticKeyring();
    output := Types.DynamoDbItemEncryptorConfig(
      tableName := "foo",
      partitionKeyName := "bar",
      sortKeyName := None(),
      attributeActions := GetAttributeActions(),
      allowedUnauthenticatedAttributes := None(),
      allowedUnauthenticatedAttributePrefix := None(),
      keyring := Some(keyring),
      cmm := None()
    );
  }

  method GetDynamoDbItemEncryptorFrom(config : Types.DynamoDbItemEncryptorConfig)
    returns (encryptor: DynamoDbItemEncryptor.DynamoDbItemEncryptorClient)
    ensures encryptor.ValidState()
    ensures fresh(encryptor)
    ensures fresh(encryptor.Modifies)
  {
    var keyring := GetStaticKeyring();
    var encryptorConfig := Types.DynamoDbItemEncryptorConfig(
      tableName := config.tableName,
      partitionKeyName := config.partitionKeyName,
      sortKeyName := config.sortKeyName,
      attributeActions := config.attributeActions,
      allowedUnauthenticatedAttributes := config.allowedUnauthenticatedAttributes,
      allowedUnauthenticatedAttributePrefix := config.allowedUnauthenticatedAttributePrefix,
      keyring := Some(keyring),
      cmm := None()
    );
    encryptor :- expect DynamoDbItemEncryptor.DynamoDbItemEncryptor(encryptorConfig);
  }

  method GetDynamoDbItemEncryptor()
      returns (encryptor: DynamoDbItemEncryptor.DynamoDbItemEncryptorClient)
    ensures encryptor.ValidState()
    ensures fresh(encryptor)
    ensures fresh(encryptor.Modifies)
  {
    var config := GetEncryptorConfig();
    encryptor := GetDynamoDbItemEncryptorFrom(config);
  }
}