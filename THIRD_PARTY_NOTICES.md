# Shan Shui reference

The Shan Shui studies adapt mountain-envelope, contour texture, tapered strokes,
leaf blobs, branching trees, roof perspective and boat/figure geometry from
[shan-shui-inf](https://github.com/LingDong-/shan-shui-inf)
by Lingdong Huang. The Swift implementation uses a different random sequence
and renderer; it does not reproduce the JavaScript seed sequence.

The element study references `Tree.tree03`, `Tree.tree08`/`fracTree`, `Arch.roof`,
`box`, `rail`, `boat01`, `Man.man` and `hat02` in upstream `index.html`. It adapts
those routines to ordered Swift ink primitives with a local random stream and
bounded study dimensions. It is not an exact SVG or same-seed reproduction.

## Upstream MIT license

MIT License

Copyright (c) 2018 Lingdong Huang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
