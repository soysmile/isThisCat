//
//  ViewController.swift
//  isThisCat
//
//  Created by George Heints on 25.05.2018.
//  Copyright © 2018 George Heints. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

    @IBOutlet weak var resultView: UIView!
    @IBOutlet weak var resultLabel: UILabel!

    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let captureQueue = DispatchQueue(label: "captureQueue")

    //Request to Vision
    var visionRequest = [VNRequest]()

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        do{
            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            resultView.layer.addSublayer(previewLayer)

            //cameraInput & cameraOutput settings
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self as AVCaptureVideoDataOutputSampleBufferDelegate, queue: captureQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            session.sessionPreset = .high
            session.addInput(cameraInput)
            session.addOutput(videoOutput)

            let connection = videoOutput.connection(with: .video)
            connection?.videoOrientation = .portrait
            session.startRunning()

            //CoreML init for Vision
            guard let visionModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
                fatalError("Could not load model")
            }

            let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)

            classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
            visionRequest = [classificationRequest]

        }catch{
            let alertController = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
        }

    }
    override func viewDidLayoutSubviews() {

        previewLayer.frame = view.frame
    }

    private func handleClassifications(request: VNRequest, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        guard let results = request.results as? [VNClassificationObservation] else {
            print("No results")
            return
        }

        var resultString = "Это не кот!"
        results[0...3].forEach {
            let identifer = $0.identifier.lowercased()
            if identifer.range(of: " cat") != nil || identifer.range(of: "cat ") != nil || identifer == "cat" {
                resultString = "Это кот!"
            }
        }
        DispatchQueue.main.async {
            self.resultLabel.text = resultString
        }
    }


}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        var requestOptions: [VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 1)!, options: requestOptions)
        do {
            try imageRequestHandler.perform(visionRequest)
        } catch {
            print(error)
        }
    }
}
