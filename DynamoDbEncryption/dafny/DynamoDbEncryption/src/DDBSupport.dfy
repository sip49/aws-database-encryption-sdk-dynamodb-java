// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/*
  Modified DDB calls share a lot of infrastructure.
  This file captures that commonality, implementing the things in ddb-support.md
*/

include "Util.dfy"
include "UpdateExpr.dfy"
include "FilterExpr.dfy"
include "Virtual.dfy"
include "SearchInfo.dfy"
include "DDBIndex.dfy"

module DynamoDBSupport {

  import DDB = ComAmazonawsDynamodbTypes
  import opened AwsCryptographyDynamoDbEncryptionTypes
  import opened Wrappers
  import opened StandardLibrary
  import opened StandardLibrary.UInt
  import opened DynamoDbEncryptionUtil
  import opened DdbVirtualFields
  import opened DynamoDBIndexSupport
  import opened SearchableEncryptionInfo
  import UTF8
  import SortedSets
  import Seq
  import Update = DynamoDbUpdateExpr
  import Filter = DynamoDBFilterExpr


  // IsWritable examines an AttributeMap and fails if it is unsuitable for writing.
  // At the moment, this means that no attribute names starts with "aws_dbe_",
  // as all other attribute names would need to be configured, and all the
  // other weird constraints were checked at configuration time.
  function method IsWriteable(item : DDB.AttributeMap)
    : Result<bool, string>
  {
    if forall k <- item :: !(ReservedPrefix <= k) then
      Success(true)
    else
      var bad := set k <- item | ReservedPrefix <= k;
      var badSeq := SortedSets.ComputeSetToOrderedSequence2(bad, CharLess);
      if |badSeq| == 0 then
        Failure("")
      else
        Failure("Writing reserved attributes not allowed : " + Join(badSeq, "\n"))
  }

  function method GetEncryptedAttributes(
    actions : AttributeActions,
    expr : Option<string>,
    attrNames : Option<DDB.ExpressionAttributeNameMap> )
    : seq<string>
  {
    if expr.None? then
      []
    else
      var attrs := Filter.ExtractAttributes(expr.value, attrNames);
      Seq.Filter((attr : string) => IsEncrypted(actions, attr), attrs)
  }


  // TestConditionExpression fails if a condition expression is not suitable for the
  // given encryption schema.
  // Generally this means no encrypted attribute is referenced.
  function method TestConditionExpression(
    actions : AttributeActions,
    expr: Option<DDB.ConditionExpression>,
    attrNames: Option<DDB.ExpressionAttributeNameMap>,
    attrValues: Option<DDB.ExpressionAttributeValueMap>
  )
    : Result<bool, string>
  {
    if expr.Some? then
      var attrs := GetEncryptedAttributes(actions, expr, attrNames);
      if |attrs| == 0 then
        Success(true)
      else
        Failure("Condition Expressions forbidden on encrypted attributes : " + Join(attrs, ","))
    else
      Success(true)
  }

  predicate method IsSigned(actions : AttributeActions, attr : string)
  {
    && attr in actions
    && actions[attr] != SET.DO_NOTHING
  }

  predicate method IsEncrypted(actions : AttributeActions, attr : string)
  {
    && attr in actions
    && actions[attr] == SET.ENCRYPT_AND_SIGN
  }

  // TestUpdateExpression fails if an update expression is not suitable for the
  // given encryption schema.
  // Generally this means no signed attribute is referenced.
  function method TestUpdateExpression(
    actions : AttributeActions,
    expr: Option<DDB.UpdateExpression>,
    attrNames: Option<DDB.ExpressionAttributeNameMap>,
    attrValues: Option<DDB.ExpressionAttributeValueMap>
  )
    : Result<bool, string>
  {
    if expr.Some? then
      var attrs := Update.ExtractAttributes(expr.value, attrNames);
      var encryptedAttrs := Seq.Filter(s => IsSigned(actions, s), attrs);
      if |encryptedAttrs| == 0 then
        Success(true)
      else
        Failure("Update Expressions forbidden on signed attributes : " + Join(encryptedAttrs, ","))
    else
      Success(true)
  }

  // AddBeacons examines an AttributeMap and modifies it to be appropriate for Searchable Encryption,
  // returning a replacement AttributeMap.
  function method AddBeacons(search : Option<ValidSearchInfo>, item : DDB.AttributeMap)
    : Result<DDB.AttributeMap, string>
  {
    if search.None? then
      Success(item)
    else
      var newAttrs :- search.value.GenerateBeacons(item)
        .MapFailure(e => "Error generating beacons");
      var version : DDB.AttributeMap := map[VersionPrefix + "1" := DS(" ")];
      Success(item + newAttrs + version)
  }

  // RemoveBeacons examines an AttributeMap and modifies it to be appropriate for customer use,
  // returning a replacement AttributeMap.
  function method RemoveBeacons(search : Option<ValidSearchInfo>, item : DDB.AttributeMap)
    : Result<DDB.AttributeMap, string>
  {
    if search.None? then
      Success(item)
    else
      Success(map k <- item | (!(ReservedPrefix <= k)) :: k := item[k])
  }

  // transform optional LSIs for searchable encryption, changing AttributeDefinitions as needed
  function method LsiOptWithAttrs(
    search : ValidSearchInfo,
    actions : AttributeActions,
    schema : Option<DDB.LocalSecondaryIndexList>,
    attrs : DDB.AttributeDefinitions
  )
    : Result<(Option<DDB.LocalSecondaryIndexList>, DDB.AttributeDefinitions), Error>
  {
    if schema.None? then
      Success((schema, []))
    else
      var (newSchema, newAttrs) :- LsiWithAttrs(search, actions, schema.value, attrs);
      Success((Some(newSchema), newAttrs))
  }

  // transform optional GSIs for searchable encryption, changing AttributeDefinitions as needed
  function method GsiOptWithAttrs(
    search : ValidSearchInfo,
    actions : AttributeActions,
    schema : Option<DDB.GlobalSecondaryIndexList>,
    attrs : DDB.AttributeDefinitions
  )
    : Result<(Option<DDB.GlobalSecondaryIndexList>, DDB.AttributeDefinitions), Error>
  {
    if schema.None? then
      Success((schema, []))
    else
      var (newSchema, newAttrs) :- GsiWithAttrs(search, actions, schema.value, attrs);
      Success((Some(newSchema), newAttrs))
  }

  // Transform a CreateTableInput object for searchable encryption.
  function method CreateTableInputForBeacons(
    search : Option<ValidSearchInfo>,
    actions : AttributeActions,
    req : DDB.CreateTableInput
  )
    : Result<DDB.CreateTableInput, Error>
  {
    if search.None? then
      Success(req)
    else
      var (newSchema, newAttrs) :- AddBeaconsToKeySchema(search.value, actions, req.KeySchema, req.AttributeDefinitions);
      var (newLsi, newAttrs) :- LsiOptWithAttrs(search.value, actions, req.LocalSecondaryIndexes, newAttrs);
      var (newGsi, newAttrs) :- GsiOptWithAttrs(search.value, actions, req.GlobalSecondaryIndexes, newAttrs);
      Success(req.(
        KeySchema := newSchema,
        AttributeDefinitions := newAttrs,
        LocalSecondaryIndexes := newLsi,
        GlobalSecondaryIndexes := newGsi
      ))
  }

  // Transform a UpdateTableInput object for searchable encryption.
  function method UpdateTableInputForBeacons(
    search : Option<ValidSearchInfo>,
    actions : AttributeActions,
    req : DDB.UpdateTableInput
  )
    : Result<DDB.UpdateTableInput, Error>
  {
    if search.None? || req.GlobalSecondaryIndexUpdates.None? then
      Success(req)
    else
      var (indexes, attrs) :- TransformIndexUpdates(search.value, actions, req.GlobalSecondaryIndexUpdates.value, req.AttributeDefinitions.UnwrapOr([]));
      var newAttrs := if |attrs| == 0 then None else Some(attrs);
      Success(req.(GlobalSecondaryIndexUpdates := Some(indexes), AttributeDefinitions := newAttrs))
  }

  // Transform a DescribeTableOutput object for searchable encryption.
  function method DescribeTableOutputForBeacons(search : Option<ValidSearchInfo>, req : DDB.DescribeTableOutput)
    : Result<DDB.DescribeTableOutput, Error>
  {
    if search.None? || req.Table.None? then
      Success(req)
    else
      var locals :- TransformLocalIndexDescription(req.Table.value.LocalSecondaryIndexes);
      var globals :- TransformGlobalIndexDescription(req.Table.value.GlobalSecondaryIndexes);
      Success(
        DDB.DescribeTableOutput(
          Table := Some(
            req.Table.value.(LocalSecondaryIndexes := locals, GlobalSecondaryIndexes := globals)
          )
        )
      )
  }

  // Transform a QueryInput object for searchable encryption.
  function method QueryInputForBeacons(search : Option<ValidSearchInfo>, req : DDB.QueryInput)
    : Result<DDB.QueryInput, Error>
  {
    if search.None? then
      Success(req)
    else
      var context1 := Filter.ExprContext(req.KeyConditionExpression, req.ExpressionAttributeValues, req.ExpressionAttributeNames);
      var context2 :- Filter.Beaconize(search.value.curr(), context1);
      var context3 := context2.(expr := req.FilterExpression);
      var context4 :- Filter.Beaconize(search.value.curr(), context3);
      Success(req.(
        KeyConditionExpression := context2.expr,
        FilterExpression := context4.expr,
        ExpressionAttributeNames := context4.names,
        ExpressionAttributeValues := context4.values
      ))
  }

  // Transform a QueryOutput object for searchable encryption.
  function method QueryOutputForBeacons(search : Option<ValidSearchInfo>, req : DDB.QueryInput, resp : DDB.QueryOutput)
    : (ret : Result<DDB.QueryOutput, Error>)
    requires resp.Items.Some?
    ensures ret.Success? ==> ret.value.Items.Some?
  {
    if search.None? || resp.Items.None? then
      Success(resp)
    else
      var newItems :- Filter.FilterResults(
        search.value.curr(),
        resp.Items.value,
        req.KeyConditionExpression,
        req.FilterExpression,
        req.ExpressionAttributeNames,
        req.ExpressionAttributeValues);
      :- Need(|newItems| < INT32_MAX_LIMIT, DynamoDbEncryptionUtil.E("This is impossible."));
      var count :=
        if resp.Count.Some? then
          Some(|newItems| as DDB.Integer)
        else
          None;
      Success(resp.(Items := Some(newItems), Count := count))
  }

  // Transform a ScanInput object for searchable encryption.
  function method ScanInputForBeacons(search : Option<ValidSearchInfo>, req : DDB.ScanInput)
    : Result<DDB.ScanInput, Error>
  {
    if search.None? then
      Success(req)
    else
      var context := Filter.ExprContext(req.FilterExpression, req.ExpressionAttributeValues, req.ExpressionAttributeNames);
      var newContext :- Filter.Beaconize(search.value.curr(), context);
      Success(req.(
        FilterExpression := newContext.expr,
        ExpressionAttributeNames := newContext.names,
        ExpressionAttributeValues := newContext.values
      ))
  }

  // Transform a ScanOutput object for searchable encryption.
  function method ScanOutputForBeacons(search : Option<ValidSearchInfo>, req : DDB.ScanInput, resp : DDB.ScanOutput)
    : (ret : Result<DDB.ScanOutput, Error>)
    requires resp.Items.Some?
    ensures ret.Success? ==> ret.value.Items.Some?
  {
    if search.None? then
      Success(resp)
    else
      var newItems :- Filter.FilterResults(
        search.value.curr(),
        resp.Items.value,
        None,
        req.FilterExpression,
        req.ExpressionAttributeNames,
        req.ExpressionAttributeValues);
      :- Need(|newItems| < INT32_MAX_LIMIT, DynamoDbEncryptionUtil.E("This is impossible."));
      var count :=
        if resp.Count.Some? then
          Some(|newItems| as DDB.Integer)
        else
          None;
      Success(resp.(Items := Some(newItems), Count := count))
  }
}
