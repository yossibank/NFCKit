#if canImport(CoreNFC)
import CoreNFC
import NFCCore

@MainActor
final class NFCConnection: NSObject {
    private var session: NFCTagReaderSession?

    private var tag: (any NFCISO7816Tag)?

    private var detection: CheckedContinuation<
        Result<Void, TransportError>,
        Never
    >?

    private var isEnded = false

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

        try await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, TransportError>, Never>) in
            session.connect(to: .iso7816(tag)) { error in
                if let error {
                    continuation.resume(
                        returning: .failure(
                            TransportError(error)
                        )
                    )
                } else {
                    continuation.resume(
                        returning: .success(())
                    )
                }
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
                continuation.resume(
                    returning: result
                        .map {
                            ResponseAPDU(
                                data: $0.payload ?? Data(),
                                statusWord: StatusWord(
                                    sw1: $0.statusWord1,
                                    sw2: $0.statusWord2
                                )
                            )
                        }
                        .mapError { TransportError($0) }
                )
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

    private func finishDetection(_ result: Result<Void, TransportError>) {
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

