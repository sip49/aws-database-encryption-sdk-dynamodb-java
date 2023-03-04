// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
// Do not modify this file. This file is machine generated, and any changes to it will be overwritten.
package software.amazon.cryptography.dynamoDbItemEncryptor.model;

// TODO manually updated the below DDB import to point to the right place
// TODO manually updated native type name, i.e. Input->Request Output->Result
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import java.util.Map;
import java.util.Objects;

public class DecryptItemOutput {
  private final Map<String, AttributeValue> plaintextItem;

  protected DecryptItemOutput(BuilderImpl builder) {
    this.plaintextItem = builder.plaintextItem();
  }

  public Map<String, AttributeValue> plaintextItem() {
    return this.plaintextItem;
  }

  public Builder toBuilder() {
    return new BuilderImpl(this);
  }

  public static Builder builder() {
    return new BuilderImpl();
  }

  public interface Builder {
    Builder plaintextItem(Map<String, AttributeValue> plaintextItem);

    Map<String, AttributeValue> plaintextItem();

    DecryptItemOutput build();
  }

  static class BuilderImpl implements Builder {
    protected Map<String, AttributeValue> plaintextItem;

    protected BuilderImpl() {
    }

    protected BuilderImpl(DecryptItemOutput model) {
      this.plaintextItem = model.plaintextItem();
    }

    public Builder plaintextItem(Map<String, AttributeValue> plaintextItem) {
      this.plaintextItem = plaintextItem;
      return this;
    }

    public Map<String, AttributeValue> plaintextItem() {
      return this.plaintextItem;
    }

    public DecryptItemOutput build() {
      if (Objects.isNull(this.plaintextItem()))  {
        throw new IllegalArgumentException("Missing value for required field `plaintextItem`");
      }
      return new DecryptItemOutput(this);
    }
  }
}