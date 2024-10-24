/*
 * Copyright (C) 2019 Google LLC
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
package com.google.cloud.teleport.templates;

import com.google.api.services.bigquery.model.TableFieldSchema;
import com.google.cloud.teleport.metadata.Template;
import com.google.cloud.teleport.metadata.TemplateCategory;
import com.google.cloud.teleport.metadata.TemplateParameter;
import com.google.cloud.teleport.templates.BigQueryToTFRecord.Options;
import com.google.cloud.teleport.templates.common.BigQueryConverters.BigQueryReadOptions;
import com.google.protobuf.ByteString;
import java.util.Iterator;
import java.util.Random;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.avro.util.Utf8;
import org.apache.beam.sdk.Pipeline;
import org.apache.beam.sdk.PipelineResult;
import org.apache.beam.sdk.coders.ByteArrayCoder;
import org.apache.beam.sdk.io.FileIO;
import org.apache.beam.sdk.io.TFRecordIO;
import org.apache.beam.sdk.io.gcp.bigquery.BigQueryIO;
import org.apache.beam.sdk.io.gcp.bigquery.SchemaAndRecord;
import org.apache.beam.sdk.options.Default;
import org.apache.beam.sdk.options.PipelineOptionsFactory;
import org.apache.beam.sdk.options.ValueProvider;
import org.apache.beam.sdk.transforms.Partition;
import org.apache.beam.sdk.transforms.Reshuffle;
import org.apache.beam.sdk.values.PCollection;
import org.apache.beam.sdk.values.PCollectionList;
import org.apache.beam.vendor.guava.v32_1_2_jre.com.google.common.annotations.VisibleForTesting;
import org.tensorflow.example.Example;
import org.tensorflow.example.Feature;
import org.tensorflow.example.Features;

/**
 * Dataflow template which reads BigQuery data and writes it to GCS as a set of TFRecords. The
 * source is a SQL query.
 *
 * <p>Check out <a
 * href="https://github.com/GoogleCloudPlatform/DataflowTemplates/blob/main/v1/README_Cloud_BigQuery_to_GCS_TensorFlow_Records.md">README</a>
 * for instructions on how to use or modify this template.
 */
@Template(
    name = "Cloud_BigQuery_to_GCS_TensorFlow_Records",
    category = TemplateCategory.BATCH,
    displayName = "BigQuery to TensorFlow Records",
    description =
        "The BigQuery to Cloud Storage TFRecords template is a pipeline that reads data from a BigQuery query and writes it to a Cloud Storage bucket in TFRecord format. "
            + "You can specify the training, testing, and validation percentage splits. "
            + "By default, the split is 1 or 100% for the training set and 0 or 0% for testing and validation sets. "
            + "When setting the dataset split, the sum of training, testing, and validation needs to add up to 1 or 100% (for example, 0.6+0.2+0.2). "
            + "Dataflow automatically determines the optimal number of shards for each output dataset.",
    optionsClass = Options.class,
    optionsOrder = {BigQueryReadOptions.class, Options.class},
    documentation =
        "https://cloud.google.com/dataflow/docs/guides/templates/provided/bigquery-to-tfrecords",
    contactInformation = "https://cloud.google.com/support",
    requirements = {
      "The BigQuery dataset and table must exist.",
      "The output Cloud Storage bucket must exist before pipeline execution. Training, testing, and validation subdirectories don't need to preexist and are autogenerated."
    })
public class BigQueryToTFRecord {

  /**
   * The {@link BigQueryToTFRecord#buildFeatureFromIterator(Class, Object, Feature.Builder)} method
   * handles {@link GenericData.Array} that are passed into the {@link
   * BigQueryToTFRecord#buildFeature} method creating a TensorFlow feature from the record.
   */
  private static final String TRAIN = "train/";

  private static final String TEST = "test/";
  private static final String VAL = "val/";

  private static void buildFeatureFromIterator(
      Class<?> fieldType, Object field, Feature.Builder feature) {
    ByteString byteString;
    GenericData.Array f = (GenericData.Array) field;
    if (fieldType == Long.class) {
      Iterator<Long> longIterator = f.iterator();
      while (longIterator.hasNext()) {
        Long longValue = longIterator.next();
        feature.getInt64ListBuilder().addValue(longValue);
      }
    } else if (fieldType == double.class) {
      Iterator<Double> doubleIterator = f.iterator();
      while (doubleIterator.hasNext()) {
        double doubleValue = doubleIterator.next();
        feature.getFloatListBuilder().addValue((float) doubleValue);
      }
    } else if (fieldType == String.class) {
      Iterator<Utf8> stringIterator = f.iterator();
      while (stringIterator.hasNext()) {
        String stringValue = stringIterator.next().toString();
        byteString = ByteString.copyFromUtf8(stringValue);
        feature.getBytesListBuilder().addValue(byteString);
      }
    } else if (fieldType == boolean.class) {
      Iterator<Boolean> booleanIterator = f.iterator();
      while (booleanIterator.hasNext()) {
        Boolean boolValue = booleanIterator.next();
        int boolAsInt = boolValue ? 1 : 0;
        feature.getInt64ListBuilder().addValue(boolAsInt);
      }
    }
  }

  /**
   * The {@link BigQueryToTFRecord#buildFeature} method takes in an individual field and type
   * corresponding to a column value from a SchemaAndRecord Object returned from a BigQueryIO.read()
   * step. The method builds a TensorFlow Feature based on the type of the object- ie: STRING, TIME,
   * INTEGER etc..
   */
  private static Feature buildFeature(Object field, String type) {
    Feature.Builder feature = Feature.newBuilder();
    ByteString byteString;

    switch (type) {
      case "STRING":
      case "TIME":
      case "DATE":
        if (field instanceof GenericData.Array) {
          buildFeatureFromIterator(String.class, field, feature);
        } else {
          byteString = ByteString.copyFromUtf8(field.toString());
          feature.getBytesListBuilder().addValue(byteString);
        }
        break;
      case "BYTES":
        byteString = ByteString.copyFrom((byte[]) field);
        feature.getBytesListBuilder().addValue(byteString);
        break;
      case "INTEGER":
      case "INT64":
      case "TIMESTAMP":
        if (field instanceof GenericData.Array) {
          buildFeatureFromIterator(Long.class, field, feature);
        } else {
          feature.getInt64ListBuilder().addValue((long) field);
        }
        break;
      case "FLOAT":
      case "FLOAT64":
        if (field instanceof GenericData.Array) {
          buildFeatureFromIterator(double.class, field, feature);
        } else {
          feature.getFloatListBuilder().addValue((float) (double) field);
        }
        break;
      case "BOOLEAN":
      case "BOOL":
        if (field instanceof GenericData.Array) {
          buildFeatureFromIterator(boolean.class, field, feature);
        } else {
          int boolAsInt = (boolean) field ? 1 : 0;
          feature.getInt64ListBuilder().addValue(boolAsInt);
        }
        break;
      default:
        throw new RuntimeException("Unsupported type: " + type);
    }
    return feature.build();
  }

  /**
   * The {@link BigQueryToTFRecord#record2Example(SchemaAndRecord)} method uses takes in a
   * SchemaAndRecord Object returned from a BigQueryIO.read() step and builds a TensorFlow Example
   * from the record.
   */
  @VisibleForTesting
  protected static byte[] record2Example(SchemaAndRecord schemaAndRecord) {
    Example.Builder example = Example.newBuilder();
    Features.Builder features = example.getFeaturesBuilder();
    GenericRecord record = schemaAndRecord.getRecord();
    for (TableFieldSchema field : schemaAndRecord.getTableSchema().getFields()) {
      Object fieldValue = record.get(field.getName());
      if (fieldValue != null) {
        Feature feature = buildFeature(fieldValue, field.getType());
        features.putFeature(field.getName(), feature);
      }
    }
    return example.build().toByteArray();
  }

  /**
   * The {@link BigQueryToTFRecord#concatURI} method uses takes in a Cloud Storage URI and a
   * subdirectory name and safely concatenates them. The resulting String is used as a sink for
   * TFRecords.
   */
  private static String concatURI(String dir, String folder) {
    if (dir.endsWith("/")) {
      return dir + folder;
    } else {
      return dir + "/" + folder;
    }
  }

  /**
   * The {@link BigQueryToTFRecord#applyTrainTestValSplit} method transforms the PCollection by
   * randomly partitioning it into PCollections for each dataset.
   */
  static PCollectionList<byte[]> applyTrainTestValSplit(
      PCollection<byte[]> input,
      ValueProvider<Float> trainingPercentage,
      ValueProvider<Float> testingPercentage,
      ValueProvider<Float> validationPercentage,
      Random rand) {
    return input.apply(
        Partition.of(
            3,
            (Partition.PartitionFn<byte[]>)
                (number, numPartitions) -> {
                  Float train = trainingPercentage.get();
                  Float test = testingPercentage.get();
                  Float validation = validationPercentage.get();
                  Double d = rand.nextDouble();
                  if (train + test + validation != 1) {
                    throw new RuntimeException(
                        String.format(
                            "Train %.2f, Test %.2f, Validation"
                                + " %.2f percentages must add up to 100 percent",
                            train, test, validation));
                  }
                  if (d < train) {
                    return 0;
                  } else if (d >= train && d < train + test) {
                    return 1;
                  } else {
                    return 2;
                  }
                }));
  }

  /** Run the pipeline. */
  public static void main(String[] args) {
    Options options = PipelineOptionsFactory.fromArgs(args).withValidation().as(Options.class);
    run(options);
  }

  /**
   * Runs the pipeline to completion with the specified options. This method does not wait until the
   * pipeline is finished before returning. Invoke {@code result.waitUntilFinish()} on the result
   * object to block until the pipeline is finished running if blocking programmatic execution is
   * required.
   *
   * @param options The execution options.
   * @return The pipeline result.
   */
  public static PipelineResult run(Options options) {
    Random rand = new Random(100); // set random seed
    Pipeline pipeline = Pipeline.create(options);

    PCollection<byte[]> bigQueryToExamples =
        pipeline
            .apply(
                "RecordToExample",
                BigQueryIO.read(BigQueryToTFRecord::record2Example)
                    .fromQuery(options.getReadQuery())
                    .withCoder(ByteArrayCoder.of())
                    .withTemplateCompatibility()
                    .withoutValidation()
                    .usingStandardSql()
                    .withMethod(BigQueryIO.TypedRead.Method.DIRECT_READ)
                // Enable BigQuery Storage API
                )
            .apply("ReshuffleResults", Reshuffle.viaRandomKey());

    PCollectionList<byte[]> partitionedExamples =
        applyTrainTestValSplit(
            bigQueryToExamples,
            options.getTrainingPercentage(),
            options.getTestingPercentage(),
            options.getValidationPercentage(),
            rand);

    partitionedExamples
        .get(0)
        .apply(
            "WriteTFTrainingRecord",
            FileIO.<byte[]>write()
                .via(TFRecordIO.sink())
                .to(
                    ValueProvider.NestedValueProvider.of(
                        options.getOutputDirectory(), dir -> concatURI(dir, TRAIN)))
                .withNumShards(0)
                .withSuffix(options.getOutputSuffix()));

    partitionedExamples
        .get(1)
        .apply(
            "WriteTFTestingRecord",
            FileIO.<byte[]>write()
                .via(TFRecordIO.sink())
                .to(
                    ValueProvider.NestedValueProvider.of(
                        options.getOutputDirectory(), dir -> concatURI(dir, TEST)))
                .withNumShards(0)
                .withSuffix(options.getOutputSuffix()));

    partitionedExamples
        .get(2)
        .apply(
            "WriteTFValidationRecord",
            FileIO.<byte[]>write()
                .via(TFRecordIO.sink())
                .to(
                    ValueProvider.NestedValueProvider.of(
                        options.getOutputDirectory(), dir -> concatURI(dir, VAL)))
                .withNumShards(0)
                .withSuffix(options.getOutputSuffix()));

    return pipeline.run();
  }

  /** Define command line arguments. */
  public interface Options extends BigQueryReadOptions {

    @TemplateParameter.GcsWriteFolder(
        order = 1,
        groupName = "Target",
        description = "Output Cloud Storage directory.",
        helpText =
            "The top-level Cloud Storage path prefix to use when writing the training, testing, and validation TFRecord files. Subdirectories for resulting training, testing, and validation TFRecord files are automatically generated from `outputDirectory`. For example, `gs://mybucket/output/train`",
        example = "gs://mybucket/output")
    ValueProvider<String> getOutputDirectory();

    void setOutputDirectory(ValueProvider<String> outputDirectory);

    @TemplateParameter.Text(
        order = 2,
        groupName = "Target",
        optional = true,
        regexes = {"^[A-Za-z_0-9.]*"},
        description = "The output suffix for TFRecord files",
        helpText =
            "The file suffix for the training, testing, and validation TFRecord files that are written. The default value is `.tfrecord`.")
    @Default.String(".tfrecord")
    ValueProvider<String> getOutputSuffix();

    void setOutputSuffix(ValueProvider<String> outputSuffix);

    @TemplateParameter.Float(
        order = 3,
        optional = true,
        description = "Percentage of data to be in the training set ",
        helpText =
            "The percentage of query data allocated to training TFRecord files. The default value is 1, or 100%.")
    @Default.Float(1)
    ValueProvider<Float> getTrainingPercentage();

    void setTrainingPercentage(ValueProvider<Float> trainingPercentage);

    @TemplateParameter.Float(
        order = 4,
        optional = true,
        description = "Percentage of data to be in the testing set ",
        helpText =
            "The percentage of query data allocated to testing TFRecord files. The default value is 0, or 0%.")
    @Default.Float(0)
    ValueProvider<Float> getTestingPercentage();

    void setTestingPercentage(ValueProvider<Float> testingPercentage);

    @TemplateParameter.Float(
        order = 5,
        optional = true,
        description = "Percentage of data to be in the validation set ",
        helpText =
            "The percentage of query data allocated to validation TFRecord files. The default value is 0, or 0%.")
    @Default.Float(0)
    ValueProvider<Float> getValidationPercentage();

    void setValidationPercentage(ValueProvider<Float> validationPercentage);
  }
}