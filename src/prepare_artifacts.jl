# Standalone script to generate the artifact information for `../Artifact.toml`
ver_str = "v0.0.12-DEV"
fname = "shared_libs.tar.gz"
url = "https://github.com/manuelbb-upb/DFMO/releases/download/$(ver_str)/$(fname)"

using Pkg
current_env = first(Base.load_path())
env_has_Inflate = false
try
    global env_has_Inflate
    Pkg.activate(; temp=true)
    Pkg.add("Inflate")
    env_has_Inflate = true
catch
    @warn "Could not install `Inflate`"
end

function print_toml(git_tree_sha1_str, sha256_str)
    global url
    println("""
    [shared_libs]
        git-tree-sha1 = \"$(git_tree_sha1_str)\"

        [[shared_libs.download]]
        url = \"$(url)\"
        sha256 = \"$(sha256_str)\"""")
end
        

if env_has_Inflate
    tmpdir = tempname()
    mkdir(tmpdir)
    fpath = joinpath(tmpdir, fname)

    using Downloads
    fpath = Downloads.download(url, fpath)

    using Tar, Inflate, SHA
    sha256_str = bytes2hex(open(sha256, fpath))
    git_tree_sha1_str = Tar.tree_hash(IOBuffer(inflate_gzip(fpath)))
    print_toml(git_tree_sha1_str, sha256_str)
end

Pkg.activate(current_env)