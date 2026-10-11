#if canImport(CoreNFC)
    import CoreNFC
    import NFCCore

    @MainActor
    final class NFCConnection: NSObject {
        private var session: NFCTagReaderSession?
        private var tag: (any NFCISO7816Tag)?
        private var detection: Detection?
        private var isEnded = false
    }

    extension NFCConnection {
        func begin(alertMessage: String) async throws(TransportError) {
            guard
                let session = NFCTagReaderSession(
                    pollingOption: .iso14443,
                    delegate: self,
                    queue: .main
                )
            else {
                throw .readingUnavailable
            }

            session.alertMessage = alertMessage
            self.session = session

            try await withCheckedContinuation { continuation in
                detection = continuation
                session.begin()
            }.get()

            guard let tag else {
                throw .tagNotFound
            }

            try await withCheckedContinuation { (continuation: Detection) in
                session.connect(to: .iso7816(tag)) { error in
                    let result: Result<Void, TransportError> = if let error {
                        .failure(TransportError(error))
                    } else {
                        .success(())
                    }

                    continuation.resume(returning: result)
                }
            }.get()
        }

        func transmit(_ command: CommandAPDU) async throws(TransportError) -> ResponseAPDU {
            guard let tag else {
                throw .connectionLost
            }

            let apdu = NFCISO7816APDU(
                instructionClass: command.cla,
                instructionCode: command.ins,
                p1Parameter: command.p1,
                p2Parameter: command.p2,
                data: command.data,
                expectedResponseLength: command.expectedLength ?? -1
            )

            return try await withCheckedContinuation { continuation in
                tag.sendCommand(apdu: apdu) { result in
                    let response = result
                        .map(ResponseAPDU.init)
                        .mapError(TransportError.init)

                    continuation.resume(returning: response)
                }
            }.get()
        }

        func end(errorMessage: String?) {
            isEnded = true

            if let errorMessage {
                session?.invalidate(errorMessage: errorMessage)
            } else {
                session?.invalidate()
            }

            session = nil
            tag = nil
        }
    }

    private extension NFCConnection {
        typealias Detection = CheckedContinuation<Result<Void, TransportError>, Never>

        func finishDetection(_ result: Result<Void, TransportError>) {
            detection?.resume(returning: result)
            detection = nil
        }
    }

    extension NFCConnection: @MainActor NFCTagReaderSessionDelegate {
        func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

        func tagReaderSession(
            _ session: NFCTagReaderSession,
            didDetect tags: [NFCTag]
        ) {
            guard
                tags.count == 1,
                case let .iso7816(tag) = tags.first
            else {
                finishDetection(.failure(.unsupportedTag))
                return
            }

            self.tag = tag
            finishDetection(.success(()))
        }

        func tagReaderSession(
            _ session: NFCTagReaderSession,
            didInvalidateWithError error: any Error
        ) {
            // 自分で invalidate() しても、ユーザーのキャンセルと同じコードが届く
            guard !isEnded else {
                return
            }

            finishDetection(.failure(TransportError(error)))
            self.session = nil
            tag = nil
        }
    }

    extension ResponseAPDU {
        init(_ response: NFCISO7816ResponseAPDU) {
            let statusWord = StatusWord(sw1: response.statusWord1, sw2: response.statusWord2)
            self.init(data: response.payload ?? Data(), statusWord: statusWord)
        }
    }

    extension TransportError {
        init(_ error: any Error) {
            switch (error as? NFCReaderError)?.code {
            case .readerSessionInvalidationErrorUserCanceled:
                self = .userCancelled

            case .readerSessionInvalidationErrorSessionTimeout:
                self = .sessionTimedOut

            case .readerErrorUnsupportedFeature,
                 .readerErrorSecurityViolation,
                 .readerErrorRadioDisabled:
                self = .readingUnavailable

            default:
                self = .connectionLost
            }
        }
    }
#endif
