/*
 *
 * Copyright 2016, Google Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
import Foundation
import CgRPC
import gRPC
import QuickProto

let address = "localhost:8080"

if let fileDescriptorSetProto = NSData(contentsOfFile:"echo.out") {
  let fileDescriptorSet = FileDescriptorSet(proto:fileDescriptorSetProto)

  gRPC.initialize()

  print("Server Starting")
  print("GRPC version " + gRPC.version())

  let server = gRPC.Server(address:address)
  server.start()

  while(true) {
    let (callError, completionType, requestHandler) = server.getNextRequest(timeout:1.0)
    if (callError != GRPC_CALL_OK) {
      print("Call error \(callError)")
      print("------------------------------")
    } else if (completionType == GRPC_OP_COMPLETE) {
      if let requestHandler = requestHandler {
        print("Received request to " + requestHandler.host()
          + " calling " + requestHandler.method()
          + " from " + requestHandler.caller())

        let (_, _, requestBuffer) = requestHandler.receiveMessage(initialMetadata:Metadata())
        if let requestBuffer = requestBuffer,
          let requestMessage = fileDescriptorSet.readMessage(name:"EchoRequest",
                                                             proto:requestBuffer.data()) {

          requestMessage.forOneField(name:"text") {(field) in

            let replyMessage = fileDescriptorSet.createMessage(name:"EchoResponse")!
            replyMessage.addField(name:"text", value:field.string())

            let (_, _) = requestHandler.sendResponse(message:ByteBuffer(data:replyMessage.serialize()),
                                                     trailingMetadata:Metadata())
          }
        }
      }
    } else if (completionType == GRPC_QUEUE_TIMEOUT) {
      // everything is fine
    } else if (completionType == GRPC_QUEUE_SHUTDOWN) {
      // we should stop
    }
  }
}
