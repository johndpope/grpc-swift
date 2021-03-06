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
import AppKit
import gRPC
import QuickProto

class StickyNoteViewController : NSViewController, NSTextFieldDelegate {
  @IBOutlet weak var messageField: NSTextField!
  @IBOutlet weak var imageView: NSImageView!

  var channel: Channel!

  var enabled = false

  @IBAction func messageReturnPressed(sender: NSTextField) {
    if enabled {
      callServer(address:"localhost:8085")
    }
  }

  override func viewDidLoad() {
    gRPC.initialize()
  }

  override func viewDidAppear() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      self.enabled = true
    }
  }

  func log(_ message: String) {
    print(message)
  }

  func callServer(address:String) {
    do {
      let fileDescriptorSet = FileDescriptorSet(filename:"stickynote.out")

      let text = self.messageField.stringValue

      // build the message
      if let requestMessage = fileDescriptorSet.makeMessage("StickyNoteRequest") {
        requestMessage.addField("message", value:text)

        let requestHost = "foo.test.google.fr"
        let requestMethod = "/messagepb.StickyNote/Get"
        let requestMetadata = Metadata([["x":"xylophone"],
                                        ["y":"yu"],
                                        ["z":"zither"]])

        channel = Channel(address:address)
        channel.host = requestHost
        let call = channel.makeCall(requestMethod)
        try call.perform(message: requestMessage.data(),
                         metadata: requestMetadata,
                         completion:
          { (callResult) in

            if let initialMetadata = callResult.initialMetadata {
              for j in 0..<initialMetadata.count() {
                self.log("Received initial metadata -> "
                  + initialMetadata.key(index:j) + " : "
                  + initialMetadata.value(index:j))
              }
            }

            self.log("Received status: \(callResult.statusCode) \(callResult.statusMessage)")

            if let responseData = callResult.resultData,
              let responseMessage = fileDescriptorSet.readMessage("StickyNoteResponse",
                                                                  data: responseData) {
              try responseMessage.forOneField("image") {(field) in
                if let image = NSImage(data: field.data() as Data) {
                  DispatchQueue.main.async {
                    self.imageView.image = image
                  }
                }
              }
            }

            if let trailingMetadata = callResult.trailingMetadata {
              for j in 0..<trailingMetadata.count() {
                self.log("Received trailing metadata -> "
                  + trailingMetadata.key(index:j) + " : "
                  + trailingMetadata.value(index:j))
              }
            }
          }
        )
      }
    } catch (let error) {
      print("Error calling server: \(error)")
    }
  }
}


