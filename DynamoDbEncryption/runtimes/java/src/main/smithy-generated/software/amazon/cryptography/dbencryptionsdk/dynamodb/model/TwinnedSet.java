// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
// Do not modify this file. This file is machine generated, and any changes to it will be overwritten.
package software.amazon.cryptography.dbencryptionsdk.dynamodb.model;

import java.util.Objects;

/**
 * Both Twinned and AsSet.
 */
public class TwinnedSet {
  /**
   * Calculate beacon values as for this beacon.
   */
  private final String other;

  protected TwinnedSet(BuilderImpl builder) {
    this.other = builder.other();
  }

  /**
   * @return Calculate beacon values as for this beacon.
   */
  public String other() {
    return this.other;
  }

  public Builder toBuilder() {
    return new BuilderImpl(this);
  }

  public static Builder builder() {
    return new BuilderImpl();
  }

  public interface Builder {
    /**
     * @param other Calculate beacon values as for this beacon.
     */
    Builder other(String other);

    /**
     * @return Calculate beacon values as for this beacon.
     */
    String other();

    TwinnedSet build();
  }

  static class BuilderImpl implements Builder {
    protected String other;

    protected BuilderImpl() {
    }

    protected BuilderImpl(TwinnedSet model) {
      this.other = model.other();
    }

    public Builder other(String other) {
      this.other = other;
      return this;
    }

    public String other() {
      return this.other;
    }

    public TwinnedSet build() {
      if (Objects.isNull(this.other()))  {
        throw new IllegalArgumentException("Missing value for required field `other`");
      }
      return new TwinnedSet(this);
    }
  }
}
