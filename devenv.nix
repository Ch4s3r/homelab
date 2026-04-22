{ pkgs, ... }: {
  packages = [ pkgs.kustomize ];

  scripts.lint-kustomize.exec = ''
    failed=0
    for dir in "$DEVENV_ROOT"/apps/*/; do
      app=$(basename "$dir")
      [ -f "$dir/kustomization.yaml" ] || continue
      output=$(kustomize build --enable-helm "$dir" 2>&1)
      if [ $? -ne 0 ]; then
        if echo "$output" | grep -qiE "sops|ksops|age|decryption"; then
          echo "SKIP (ksops): $app"
        else
          echo "FAIL: $app"
          echo "$output"
          failed=1
        fi
      else
        echo "OK: $app"
      fi
    done
    exit $failed
  '';

  tasks."devenv:enterTest" = {
    exec = "lint-kustomize";
  };
}
