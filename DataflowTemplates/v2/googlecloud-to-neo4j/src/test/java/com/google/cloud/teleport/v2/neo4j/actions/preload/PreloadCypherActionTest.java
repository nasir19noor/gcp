/*
 * Copyright (C) 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */
package com.google.cloud.teleport.v2.neo4j.actions.preload;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.google.cloud.teleport.v2.neo4j.database.Neo4jConnection;
import com.google.cloud.teleport.v2.neo4j.model.connection.ConnectionParams;
import com.google.cloud.teleport.v2.neo4j.model.job.ActionContext;
import java.util.Map;
import org.junit.Test;
import org.neo4j.driver.TransactionConfig;
import org.neo4j.importer.v1.actions.ActionStage;
import org.neo4j.importer.v1.actions.CypherAction;
import org.neo4j.importer.v1.actions.CypherExecutionMode;

public class PreloadCypherActionTest {

  private final Neo4jConnection connection = mock(Neo4jConnection.class);
  private final PreloadCypherAction preloadAction =
      new PreloadCypherAction((params, version) -> connection);

  @Test
  public void sends_transaction_metadata_for_autocommit_Cypher_preload_action() {
    var action =
        new CypherAction(
            true, "the-answer", ActionStage.START, "RETURN 42", CypherExecutionMode.AUTOCOMMIT);
    preloadAction.configure(
        action, new ActionContext(action, mock(ConnectionParams.class), "a-version"));

    preloadAction.execute();

    Map<String, String> expectedTxMetadata =
        Map.of("sink", "neo4j", "step", "cypher-preload-action", "execution", "autocommit");
    TransactionConfig expectedTransactionConfig =
        TransactionConfig.builder()
            .withMetadata(Map.of("app", "dataflow", "metadata", expectedTxMetadata))
            .build();
    verify(connection).runAutocommit("RETURN 42", expectedTransactionConfig);
  }

  @Test
  public void sends_transaction_metadata_for_transactional_Cypher_preload_action() {
    var action =
        new CypherAction(
            true, "the-answer", ActionStage.START, "RETURN 42", CypherExecutionMode.TRANSACTION);
    preloadAction.configure(
        action, new ActionContext(action, mock(ConnectionParams.class), "a-version"));

    preloadAction.execute();

    Map<String, String> expectedTxMetadata =
        Map.of("sink", "neo4j", "step", "cypher-preload-action", "execution", "transaction");
    TransactionConfig expectedTransactionConfig =
        TransactionConfig.builder()
            .withMetadata(Map.of("app", "dataflow", "metadata", expectedTxMetadata))
            .build();
    verify(connection).writeTransaction(any(), eq(expectedTransactionConfig));
  }
}