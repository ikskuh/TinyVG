let loading = false
let module = null
let render_context = null
let log_string = ''

const utf8decoder = new TextDecoder()

const wasm_binding = {
  imports: {
    imported_func: function(arg) {
      console.log(arg);
    }
  },
  platform: {
    platformPanic: (ptr, len) => {
      let msg = utf8decoder.decode(new Uint8Array(module.exports.memory.buffer, ptr, len))
      throw Error(msg)
    },
    platformLogWrite: (ptr, len) => {
      log_string += utf8decoder.decode(
        new Uint8Array(module.exports.memory.buffer, ptr, len),
      )
    },
    platformLogFlush: () => {
      console.log(log_string)
      log_string = ''
    },
  },
  tinyvg: {
    setResultSvg: (ptr, len) => {
      render_context.svg = utf8decoder.decode(new Uint8Array(module.exports.memory.buffer, ptr, len))
    },
    getSourceTvg: (ptr,len) => {
      if(len != render_context.tvg.byteLength)
        throw 'invalid byte size';

      const source = new Uint8Array(render_context.tvg);

      const destination = new Uint8Array(module.exports.memory.buffer, ptr, len)
      destination.set(source);
    },
  }
};

const wasm_ready_event_name = 'tinyvg-wasm-module-loaded';

const error_codes = {
  1: "out of memory",
  2: "end of stream",
  3: "invalid data",
  4: "unsupported version",
  5: "unsupported color format",
};

export async function load(wasm_url)
{
  if (loading) {
    return null;
  }
  loading = true;
  const blob = await fetch(wasm_url);
  const bytes = await blob.arrayBuffer();
  const result = await WebAssembly.instantiate(bytes, wasm_binding);
  // console.log("module ready:", result);
  module = result.instance;
  window.dispatchEvent(new CustomEvent(wasm_ready_event_name, {
    detail: module
  }));
}

function convertToSvg(binary_blob) {
  return new Promise((resolve, reject) => {
    function render()
    {
      const rc =  { svg: null, tvg: binary_blob } 
      let success
      try {
        render_context = rc
        success = module.exports.convertToSvg(binary_blob.byteLength)
      }
      finally {
        render_context = null
      }
      if(success == 0 && rc.svg != null) {
        resolve(rc.svg)
      }
      else if(success == 0) {
        reject("unknown");
      }
      else {
        const error_msg = error_codes[success];
        if(error_msg !== undefined) {
          reject(error_msg)
        }else {
          reject("error code " + String(success))
        }
      }
    }
    if(module == null) {
      window.addEventListener(wasm_ready_event_name, (e) => render())
    }
    else {
      render()
    }
  });
}

class TinyVGElement extends HTMLElement {
  constructor() {
    super();

    // Create a shadow root
    this.attachShadow({mode: 'open'}); // sets and returns 'this.shadowRoot'

    

    let src = this.getAttribute('src')
    if(src != null) {
      fetch(src).then((blob) => {
        return blob.arrayBuffer()
      }).then((result) => {
        return convertToSvg(result);
      }).then((code) => {
        this.shadowRoot.innerHTML = code
      });
    }
  }
}

customElements.define('tiny-vg', TinyVGElement);
