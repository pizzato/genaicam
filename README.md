# GenAICam

This app is a **proof of concept** exploring privacy-focused, on-device machine learning. It can describe what it sees and generate pictures from those descriptions — all processed locally on your device.


Created for fun as a vibe coding experiment with [OpenAI’s Codex](https://openai.com/codex/). It’s released as **open source**, so anyone is welcome to explore, adapt, and modify it. More details and reflections are shared in this [Medium story](https://medium.com/placeholder-link).

## Inspiration and attributions

Inspired by [Lingcam by Masaru Mizuochi](https://lingcam.mizumasa.net/), presented at [CVPR 2025 AI Art](https://thecvf-art.com/project/lingcam/)
                    

The project starting point was Apple’s [FastVLM repository](https://github.com/apple/ml-fastvlm), which introduced efficient vision encoding for vision-language models also at a [CVPR 2025 paper](https://openaccess.thecvf.com/content/CVPR2025/html/Vasu_FastVLM_Efficient_Vision_Encoding_for_Vision_Language_Models_CVPR_2025_paper.html)."

The image generation is done with [Apple Intelligence Playground](https://developer.apple.com/machine-learning/apple-intelligence-playground/) enabling a fully offline, on-device AI experience.

## Screenshots

<table>
    <tr>
        <td><img src="docs/GAC1.PNG" alt="GenAICam - Photo taking and live descriptions" figcaption="Photo taking and live descriptions"></td>
        <td><img src="docs/GAC2.PNG" alt="GenAICam - Generating photo with short description" figcaption="Generating photo with short description"></td>
        <td><img src="docs/GAC3.PNG" alt="GenAICam - Generated photo" figcaption="Generated photo"></td>
        <td><img src="docs/GAC4.PNG" alt="GenAICam - More screen with short and long description" figcaption="More screen with short and long description"></td>
    </tr>
</table>

## Disclaimer

This project is provided **as is**, without warranty of any kind. Use at your own risk. No guarantees are made regarding accuracy, reliability, or fitness for any purpose. By using this app, you agree that the developer is not liable for any outcomes, damages, or issues arising from its use.

## Open source and Software Licenses

This project was built on top of Apple's [FastVLM](https://github.com/apple/ml-fastvlm), see the [README](https://github.com/apple/ml-fastvlm/blob/main/README.md) for more details. I have removed the uplink to the main repository as it is not relevant to the original repository, that is, changes here should not create pull-requests over there.



---
*** 
___

Below is the original FastVLM Repo - README



# FastVLM: Efficient Vision Encoding for Vision Language Models

This is the official repository of
**[FastVLM: Efficient Vision Encoding for Vision Language Models](https://www.arxiv.org/abs/2412.13303). (CVPR 2025)**

[//]: # (![FastViTHD Performance]&#40;docs/acc_vs_latency_qwen-2.png&#41;)
<p align="center">
<img src="docs/acc_vs_latency_qwen-2.png" alt="Accuracy vs latency figure." width="400"/>
</p>

### Highlights
* We introduce FastViTHD, a novel hybrid vision encoder designed to output fewer tokens and significantly reduce encoding time for high-resolution images.  
* Our smallest variant outperforms LLaVA-OneVision-0.5B with 85x faster Time-to-First-Token (TTFT) and 3.4x smaller vision encoder.
* Our larger variants using Qwen2-7B LLM outperform recent works like Cambrian-1-8B while using a single image encoder with a 7.9x faster TTFT.
* Demo iOS app to demonstrate the performance of our model on a mobile device.

<table>
<tr>
    <td><img src="docs/fastvlm-counting.gif" alt="FastVLM - Counting"></td>
    <td><img src="docs/fastvlm-handwriting.gif" alt="FastVLM - Handwriting"></td>
    <td><img src="docs/fastvlm-emoji.gif" alt="FastVLM - Emoji"></td>
</tr>
</table>

## Getting Started
We use LLaVA codebase to train FastVLM variants. In order to train or finetune your own variants, 
please follow instructions provided in [LLaVA](https://github.com/haotian-liu/LLaVA) codebase. 
We provide instructions for running inference with our models.   

### Setup
```bash
conda create -n fastvlm python=3.10
conda activate fastvlm
pip install -e .
```

### Model Zoo
For detailed information on various evaluations, please refer to our [paper](https://www.arxiv.org/abs/2412.13303).

| Model        | Stage |                                            Pytorch Checkpoint (url)                                             |
|:-------------|:-----:|:---------------------------------------------------------------------------------------------------------------:|
| FastVLM-0.5B |   2   | [fastvlm_0.5b_stage2](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_0.5b_stage2.zip) |
|              |   3   | [fastvlm_0.5b_stage3](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_0.5b_stage3.zip) |
| FastVLM-1.5B |   2   | [fastvlm_1.5b_stage2](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_1.5b_stage2.zip) |
|              |   3   | [fastvlm_1.5b_stage3](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_1.5b_stage3.zip)  |
| FastVLM-7B   |   2   | [fastvlm_7b_stage2](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_7b_stage2.zip)  |
|              |   3   | [fastvlm_7b_stage3](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_7b_stage3.zip)  |

To download all the pretrained checkpoints run the command below (note that this might take some time depending on your connection so might be good to grab ☕️ while you wait).

```bash
bash get_models.sh   # Files will be downloaded to `checkpoints` directory.
```

### Usage Example
To run inference of PyTorch checkpoint, follow the instruction below
```bash
python predict.py --model-path /path/to/checkpoint-dir \
                  --image-file /path/to/image.png \
                  --prompt "Describe the image."
```

### Inference on Apple Silicon
To run inference on Apple Silicon, pytorch checkpoints have to be exported to format 
suitable for running on Apple Silicon, detailed instructions and code can be found [`model_export`](model_export/) subfolder.
Please see the README there for more details.

For convenience, we provide 3 models that are in Apple Silicon compatible format: [fastvlm_0.5b_stage3](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_0.5b_stage3_llm.fp16.zip), 
[fastvlm_1.5b_stage3](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_1.5b_stage3_llm.int8.zip), 
[fastvlm_7b_stage3](https://ml-site.cdn-apple.com/datasets/fastvlm/llava-fastvithd_7b_stage3_llm.int4.zip). 
We encourage developers to export the model of their choice with the appropriate quantization levels following 
the instructions in [`model_export`](model_export/).

### Inference on Apple Devices
To run inference on Apple devices like iPhone, iPad or Mac, see [`app`](app/) subfolder for more details.

## Citation
If you found this code useful, please cite the following paper:
```
@InProceedings{fastvlm2025,
  author = {Pavan Kumar Anasosalu Vasu, Fartash Faghri, Chun-Liang Li, Cem Koc, Nate True, Albert Antony, Gokul Santhanam, James Gabriel, Peter Grasch, Oncel Tuzel, Hadi Pouransari},
  title = {FastVLM: Efficient Vision Encoding for Vision Language Models},
  booktitle = {Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR)},
  month = {June},
  year = {2025},
}
```

## Acknowledgements
Our codebase is built using multiple opensource contributions, please see [ACKNOWLEDGEMENTS](ACKNOWLEDGEMENTS) for more details. 

## License
Please check out the repository [LICENSE](LICENSE) before using the provided code and
[LICENSE_MODEL](LICENSE_MODEL) for the released models.
