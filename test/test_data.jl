using ArviZ, DimensionalData, Test

@testset "InferenceData" begin
    var_names = (:a, :b)
    data_names = (:y,)
    coords = (
        chain=1:4, draw=1:100, shared=["s1", "s2", "s3"], dima=1:4, dimb=2:6, dimy=1:5
    )
    dims = (a=(:shared, :dima), b=(:shared, :dimb), y=(:shared, :dimy))
    metadata = (inference_library="PPL",)
    posterior = random_dataset(var_names, dims, coords, metadata)
    prior = random_dataset(var_names, dims, coords, metadata)
    observed_data = random_dataset(data_names, dims, coords, metadata)
    group_data = (; prior, observed_data, posterior)
    group_data_ordered = (; posterior, prior, observed_data)

    @testset "constructors" begin
        idata = @inferred(InferenceData(group_data))
        @test idata isa InferenceData
        @test getfield(idata, :groups) === group_data_ordered

        @test InferenceData(; group_data...) == idata
        @test InferenceData(idata) === idata
    end

    idata = InferenceData(group_data)

    @testset "properties" begin
        @test propertynames(idata) === propertynames(group_data_ordered)
        @test getproperty(idata, :posterior) === posterior
        @test getproperty(idata, :prior) === prior
        @test hasproperty(idata, :posterior)
        @test hasproperty(idata, :prior)
        @test !hasproperty(idata, :prior_predictive)
    end

    @testset "iteration" begin
        @test keys(idata) === keys(group_data_ordered)
        @test haskey(idata, :posterior)
        @test haskey(idata, :prior)
        @test !haskey(idata, :log_likelihood)
        @test values(idata) === values(group_data_ordered)
        @test pairs(idata) isa Base.Iterators.Pairs
        @test pairs(idata) === pairs(group_data_ordered)
        @test length(idata) == length(group_data_ordered)
        @test iterate(idata) === iterate(group_data_ordered)
        for i in 1:(length(idata) + 1)
            @test iterate(idata, i) === iterate(group_data_ordered, i)
        end
        @test eltype(idata) <: ArviZ.Dataset
        @test collect(idata) isa Vector{<:ArviZ.Dataset}
    end

    @testset "indexing" begin
        @test idata[:posterior] === posterior
        @test idata[:prior] === prior
        @test idata[1] === posterior
        @test idata[2] === prior

        idata_sel = idata[dima=At(2:3), dimb=At(6)]
        @test idata_sel isa InferenceData
        @test ArviZ.groupnames(idata_sel) === ArviZ.groupnames(idata)
        @test Dimensions.index(idata_sel.posterior, :dima) == 2:3
        @test Dimensions.index(idata_sel.prior, :dima) == 2:3
        @test Dimensions.index(idata_sel.posterior, :dimb) == [6]
        @test Dimensions.index(idata_sel.prior, :dimb) == [6]

        if VERSION ≥ v"1.7"
            idata_sel = idata[(:posterior, :observed_data), dimy=1, dimb=1, shared=At("s1")]
            @test idata_sel isa InferenceData
            @test ArviZ.groupnames(idata_sel) === (:posterior, :observed_data)
            @test Dimensions.index(idata_sel.posterior, :dima) == coords.dima
            @test Dimensions.index(idata_sel.posterior, :dimb) == coords.dimb[[1]]
            @test Dimensions.index(idata_sel.posterior, :shared) == ["s1"]
            @test Dimensions.index(idata_sel.observed_data, :dimy) == coords.dimy[[1]]
            @test Dimensions.index(idata_sel.observed_data, :shared) == ["s1"]
        end

        ds_sel = idata[:posterior, chain=1]
        @test ds_sel isa ArviZ.Dataset
        @test !hasdim(ds_sel, :chain)

        idata2 = Base.setindex(idata, posterior, :warmup_posterior)
        @test keys(idata2) === (keys(idata)..., :warmup_posterior)
        @test idata2[:warmup_posterior] === posterior
    end

    @testset "isempty" begin
        @test !isempty(idata)
        @test isempty(InferenceData())
    end

    @testset "groups" begin
        @test ArviZ.groups(idata) === group_data_ordered
        @test ArviZ.groups(InferenceData(; prior)) === (; prior)
    end

    @testset "hasgroup" begin
        @test ArviZ.hasgroup(idata, :posterior)
        @test ArviZ.hasgroup(idata, :prior)
        @test !ArviZ.hasgroup(idata, :prior_predictive)
    end

    @testset "groupnames" begin
        @test ArviZ.groupnames(idata) === propertynames(group_data_ordered)
        @test ArviZ.groupnames(InferenceData(; posterior)) === (:posterior,)
    end

    @testset "conversion" begin
        @test convert(InferenceData, idata) === idata
        @test convert(NamedTuple, idata) === parent(idata)
        @test NamedTuple(idata) === parent(idata)
        a = idata.posterior.a
        @test convert(InferenceData, a) isa InferenceData
        @test convert(InferenceData, a).posterior.a == a
    end

    @testset "show" begin
        @testset "plain" begin
            text = sprint(show, MIME("text/plain"), idata)
            @test text == """
            InferenceData with groups:
              > posterior
              > prior
              > observed_data"""
        end

        @testset "html" begin
            # TODO: improve test
            text = sprint(show, MIME("text/html"), idata)
            @test text isa String
            @test occursin("InferenceData", text)
            @test occursin("Dataset", text)
        end
    end
end

@testset "InferenceData <-> PyObject" begin
    idata1 = random_data()
    pyidata1 = PyObject(idata1)
    @test pyidata1 isa PyObject
    @test pyisinstance(pyidata1, ArviZ.arviz.InferenceData)
    idata2 = convert(InferenceData, pyidata1)
    test_idata_approx_equal(idata2, idata1)
end

@testset "convert_to_inference_data(obj::PyObject)" begin
    data = Dict(:z => randn(4, 100, 10))
    idata1 = convert_to_inference_data(data)
    idata2 = convert_to_inference_data(PyObject(data))
    @test idata2 isa InferenceData
    @test idata2.posterior.z ≈ collect(idata1.posterior.z)
end

@testset "extract_dataset" begin
    idata = random_data()
    post = extract_dataset(idata, :posterior; combined=false)
    for k in keys(idata.posterior)
        @test haskey(post, k)
        @test post[k] == idata.posterior[k]
        dims = DimensionalData.dims(post)
        dims_exp = DimensionalData.dims(idata.posterior)
        @test DimensionalData.name(dims) === DimensionalData.name(dims_exp)
        @test DimensionalData.index(dims) == DimensionalData.index(dims_exp)
    end
    prior = extract_dataset(idata, :prior; combined=false)
    for k in keys(idata.prior)
        @test haskey(prior, k)
        @test prior[k] == idata.prior[k]
        dims = DimensionalData.dims(prior)
        dims_exp = DimensionalData.dims(idata.prior)
        @test DimensionalData.name(dims) === DimensionalData.name(dims_exp)
        @test DimensionalData.index(dims) == DimensionalData.index(dims_exp)
    end
end

@testset "concat" begin
    data = random_data()
    idata1 = InferenceData(; posterior=data.posterior)
    idata2 = InferenceData(; prior=data.prior)
    new_idata1 = concat(idata1, idata2)
    new_idata2 = InferenceData(; posterior=data.posterior, prior=data.prior)
    test_idata_approx_equal(new_idata1, new_idata2)
end

@testset "ArviZ.convert_to_dataset(::InferenceData; kwargs...)" begin
    idata = random_data()
    @test ArviZ.convert_to_dataset(idata) === idata.posterior
    @test ArviZ.convert_to_dataset(idata; group=:prior) === idata.prior
end

@testset "ArviZ.default_var_name" begin
    x = randn(4, 5)
    @test ArviZ.default_var_name(x) === :x
    @test ArviZ.default_var_name(DimensionalData.DimArray(x, (:a, :b))) === :x
    @test ArviZ.default_var_name(DimensionalData.DimArray(x, (:a, :b); name=:y)) === :y
end

@testset "convert_to_inference_data" begin
    @testset "convert_to_inference_data(::AbstractDimStack)" begin
        ds = ArviZ.namedtuple_to_dataset((x=randn(4, 10), y=randn(4, 10, 5)))
        idata1 = convert_to_inference_data(ds; group=:prior)
        @test ArviZ.groupnames(idata1) == (:prior,)
        idata2 = InferenceData(; prior=ds)
        @test idata2 == idata1
        idata3 = convert_to_inference_data(parent(ds); group=:prior)
        @test idata3 == idata1
    end

    @testset "convert_to_inference_data(::$T)" for T in (NamedTuple, Dict)
        data = (A=randn(2, 10, 2), B=randn(2, 10, 5, 2))
        if T <: Dict
            data = Dict(pairs(data))
        end
        idata = convert_to_inference_data(data)
        check_idata_schema(idata)
        @test ArviZ.groupnames(idata) == (:posterior,)
        posterior = idata.posterior
        @test posterior.A == data[:A]
        @test posterior.B == data[:B]
        idata2 = convert_to_inference_data(data; group=:prior)
        check_idata_schema(idata2)
        @test ArviZ.groupnames(idata2) == (:prior,)
        @test idata2.prior == idata.posterior
    end

    @testset "convert_to_inference_data(::$T)" for T in (Array, DimensionalData.DimArray)
        data = randn(2, 10, 2)
        if T <: DimensionalData.DimArray
            data = DimensionalData.DimArray(data, (:a, :b, :c); name=:y)
        end
        idata = convert_to_inference_data(data)
        check_idata_schema(idata)
        @test ArviZ.groupnames(idata) == (:posterior,)
        posterior = idata.posterior
        if T <: DimensionalData.DimArray
            @test posterior.y == data
        else
            @test posterior.x == data
        end
        idata2 = convert_to_inference_data(data; group=:prior)
        check_idata_schema(idata2)
        @test ArviZ.groupnames(idata2) == (:prior,)
        @test idata2.prior == idata.posterior
    end
end

@testset "from_dict" begin
    posterior = Dict(:A => randn(2, 10, 2), :B => randn(2, 10, 5, 2))
    prior = Dict(:C => randn(2, 10, 2), :D => randn(2, 10, 5, 2))

    idata = from_dict(posterior; prior)
    check_idata_schema(idata)
    @test ArviZ.groupnames(idata) == (:posterior, :prior)
    @test idata.posterior.A == posterior[:A]
    @test idata.posterior.B == posterior[:B]
    @test idata.prior.C == prior[:C]
    @test idata.prior.D == prior[:D]

    idata2 = from_dict(; prior)
    check_idata_schema(idata2)
    @test idata2.prior == idata.prior
end

@testset "netcdf roundtrip" begin
    data = load_example_data("centered_eight")
    mktempdir() do path
        filename = joinpath(path, "tmp.nc")
        to_netcdf(data, filename)
        data2 = from_netcdf(filename)
        @test ArviZ.groupnames(data) == ArviZ.groupnames(data2)
        for (ds1, ds2) in zip(data, data2), k in keys(ds1)
            @test ds1[k] ≈ ds2[k]
        end
        data3 = convert_to_inference_data(filename)
        test_idata_approx_equal(data3, data2; check_metadata=false)
        return nothing
    end
end
