/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:grpc/grpc_web.dart';
import 'package:playground/constants/api.dart';
import 'package:playground/generated/playground.pbgrpc.dart' as grpc;
import 'package:playground/modules/editor/repository/code_repository/code_client/check_status_response.dart';
import 'package:playground/modules/editor/repository/code_repository/code_client/code_client.dart';
import 'package:playground/modules/editor/repository/code_repository/code_client/output_response.dart';
import 'package:playground/modules/editor/repository/code_repository/code_client/run_code_response.dart';
import 'package:playground/modules/editor/repository/code_repository/run_code_error.dart';
import 'package:playground/modules/editor/repository/code_repository/run_code_request.dart';
import 'package:playground/modules/editor/repository/code_repository/run_code_result.dart';
import 'package:playground/modules/sdk/models/sdk.dart';

class GrpcCodeClient implements CodeClient {
  late final GrpcWebClientChannel _channel;
  late final grpc.PlaygroundServiceClient _client;

  GrpcCodeClient() {
    _channel = GrpcWebClientChannel.xhr(
      Uri.parse(kApiClientURL),
    );
    _client = grpc.PlaygroundServiceClient(_channel);
  }

  @override
  Future<RunCodeResponse> runCode(RunCodeRequestWrapper request) {
    return _runSafely(() => _client
        .runCode(_toGrpcRequest(request))
        .then((response) => RunCodeResponse(response.pipelineUuid)));
  }

  @override
  Future<CheckStatusResponse> checkStatus(String pipelineUuid) {
    return _runSafely(() => _client
        .checkStatus(grpc.CheckStatusRequest(pipelineUuid: pipelineUuid))
        .then(
          (response) => CheckStatusResponse(_toClientStatus(response.status)),
        ));
  }

  @override
  Future<OutputResponse> getCompileOutput(String pipelineUuid) {
    return _runSafely(() => _client
        .getCompileOutput(
          grpc.GetCompileOutputRequest(pipelineUuid: pipelineUuid),
        )
        .then((response) => OutputResponse(response.output)));
  }

  @override
  Future<OutputResponse> getRunOutput(String pipelineUuid) {
    return _runSafely(() => _client
        .getRunOutput(grpc.GetRunOutputRequest(pipelineUuid: pipelineUuid))
        .then((response) => OutputResponse(response.output)));
  }

  Future<T> _runSafely<T>(Future<T> Function() invoke) {
    try {
      return invoke();
    } on GrpcError catch (error) {
      throw RunCodeError(error.message);
    }
  }

  grpc.RunCodeRequest _toGrpcRequest(RunCodeRequestWrapper request) {
    return grpc.RunCodeRequest()
      ..code = request.code
      ..sdk = _getGrpcSdk(request.sdk);
  }

  grpc.Sdk _getGrpcSdk(SDK sdk) {
    switch (sdk) {
      case SDK.java:
        return grpc.Sdk.SDK_JAVA;
      case SDK.go:
        return grpc.Sdk.SDK_GO;
      case SDK.python:
        return grpc.Sdk.SDK_PYTHON;
      case SDK.scio:
        return grpc.Sdk.SDK_SCIO;
    }
  }

  RunCodeStatus _toClientStatus(grpc.Status status) {
    switch (status) {
      case grpc.Status.STATUS_ERROR:
        return RunCodeStatus.error;
      case grpc.Status.STATUS_EXECUTING:
        return RunCodeStatus.executing;
      case grpc.Status.STATUS_FINISHED:
        return RunCodeStatus.finished;
      case grpc.Status.STATUS_UNSPECIFIED:
        return RunCodeStatus.unspecified;
    }
    return RunCodeStatus.unspecified;
  }
}
