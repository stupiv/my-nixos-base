{
  nixpkgs.overlays = [
    (final: prev: {
      myPkgs = prev.myPkgs.overrideScope (myPkgsFinal: myPkgsPrev:
        with final.myLib; {
          # See https://wordpress.org/plugins/opcache-manager/
          opcache-manager_v3 = wpPluginFetch {
            name = "opcache-manager";
            version = "3.4.0";
            hash = "sha256-giGLyfN5ld42rjcf53sIXrKpLzpMn0gSd423wR7Ts8g=";
          };
          # See https://wordpress.org/plugins/apcu-manager/
          apcu-manager_v4 = wpPluginFetch {
            name = "apcu-manager";
            version = "4.5.3";
            hash = "sha256-dr9M56hFldhwSkjXDVCOR6sZFP3N01l4K2lbrEvgKEc=";
          };
          # See https://wordpress.org/plugins/cache-enabler/
          cache-enabler_v1 = wpPluginFetch {
            name = "cache-enabler";
            version = "1.8.16";
            hash = "sha256-Rqpcrh+RjI+uCnvXFbL/3hXJHfNydlkolgcYNW4nC0Q=";
          };
          # See https://wordpress.org/plugins/two-factor/
          two-factor_v0_16 = wpPluginFetch {
            name = "two-factor";
            version = "0.16.0";
            hash = "sha256-crTZRDy9YxAcd/er0FNcjvFPrxlxVa7f5R8XRqYXjTg=";
          };
          # See https://wordpress.org/plugins/safe-svg/
          safe-svg_v2 = wpPluginFetch {
            name = "safe-svg";
            version = "2.4.0";
            hash = "sha256-p+erp9PuUg+47gAWG55pJ2C/FNqEdb8NYGKnDlVSt80=";
          };
          # See https://wordpress.org/plugins/embed-optimizer/
          embed-optimizer_v1 = wpPluginFetch {
            name = "embed-optimizer";
            version = "1.0.0-beta5";
            hash = "sha256-CPySGSfY3Wkhmtwr2Zmtb9LAb3H8lK04LuTULbUCsPg=";
          };
          # See https://wordpress.org/plugins/dominant-color-images/
          dominant-color-images_v1 = wpPluginFetch {
            name = "dominant-color-images";
            version = "1.2.1";
            hash = "sha256-tQV3Y/ywUbY1fTZUNKNdYy3bTAOY2XbRJOBcLKUgd1s=";
          };
          # See https://wordpress.org/plugins/image-prioritizer/
          image-prioritizer_v1 = wpPluginFetch {
            name = "image-prioritizer";
            version = "1.0.0-beta3";
            hash = "sha256-hiL3GlH3lzgeZKkUYhbBxSKIdAoCQOpM8GcxJhPiumc=";
          };
          # See https://wordpress.org/plugins/nocache-bfcache/
          nocache-bfcache_v1 = wpPluginFetch {
            name = "nocache-bfcache";
            version = "1.3.1";
            hash = "sha256-U/v/yl5hdlzxgV1K5BDQVFuWDcsfJk3ZjF01t1XcxUY=";
          };
          # See https://wordpress.org/plugins/webp-uploads/
          webp-uploads_v2 = wpPluginFetch {
            name = "webp-uploads";
            version = "2.7.1";
            hash = "sha256-SuxioL3taNqmLbLr0YxoPvlVVjqU7SJHOTi1XgU9o38=";
          };
          # See https://wordpress.org/plugins/optimization-detective/
          optimization-detective_v1 = wpPluginFetch {
            name = "optimization-detective";
            version = "1.0.0-beta5";
            hash = "sha256-TT7IhpgOz6Bif9cmhkrvnAlaUltL+Vv9+CI8omVipfA=";
          };
          # See https://wordpress.org/plugins/view-transitions/
          view-transitions_v1 = wpPluginFetch {
            name = "view-transitions";
            version = "1.2.1";
            hash = "sha256-RNcdPFfRuRHljuh2IhR+L/NuayreNBeLAvuAEqLMrFA=";
          };
          # See https://wordpress.org/plugins/elementor/
          elementor_v4 = wpPluginFetch {
            name = "elementor";
            version = "4.1.4";
            hash = "sha256-ANcNWYAJ/dzWHGNTEJR+FXuqjHJikixuzPP0gQ1fm2w=";
          };
          # See https://wordpress.org/themes/hello-elementor/
          hello-elementor_v3 = wpThemeFetch {
            name = "hello-elementor";
            version = "3.4.9";
            hash = "sha256-jPnb4IyC7HMm2SqJZisO09bYB5KBq8UThtJ8WlFIjwg=";
          };
        });
    })
  ];
}
