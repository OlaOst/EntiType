/**
gl3n.linalg

Special thanks to:
$(UL
  $(LI Tomasz Stachowiak (h3r3tic): allowed me to use parts of $(LINK2 https://bitbucket.org/h3r3tic/boxen/src/default/src/xf/omg, omg).)
  $(LI Jakob Øvrum (jA_cOp): improved the code a lot!)
  $(LI Florian Boesch (___doc__): helps me to understand opengl/complex maths better, see: $(LINK http://codeflow.org/).)
  $(LI #D on freenode: answered general questions about D.)
)

Authors: David Herberth
License: MIT
*/


module gl3n.linalg;

private {
    import std.math : isNaN, isInfinity, PI, abs, sqrt, sin, cos, acos, tan, asin, atan2, approxEqual;
    import std.conv : to;
    import std.traits : isFloatingPoint, isStaticArray, isDynamicArray;
    import std.string : format, rightJustify;
    import std.array : join, split, array, replace;
    import std.algorithm : max, min, reduce, map;
    import gl3n.math : clamp;
    import gl3n.util : is_vector, is_matrix, is_quaternion;
}


/// Base template for all vector-types.
/// Params:
/// type = all values get stored as this type
/// dimension = specifies the dimension of the vector, can be 1, 2, 3 or 4
/// Examples:
/// ---
/// alias Vector!(int, 3) vec3i;
/// alias Vector!(float, 4) vec4;
/// alias Vector!(real, 2) vec2r;
/// ---
struct Vector(type, int dimension_) if((dimension_ >= 2) && (dimension_ <= 4)) {
    alias type vt; /// Holds the internal type of the vector.
    static const int dimension = dimension_; ///Holds the dimension of the vector.
    
    vt[dimension] vector; /// Holds all coordinates, length conforms dimension.
    
    /// Returns a pointer to the coordinates.
    @property auto value_ptr() { return vector.ptr; }

    private @property vt get_(char coord)() const {
        return vector[coord_to_index!coord];
    }
    private @property void set_(char coord)(vt value) {
        vector[coord_to_index!coord] = value;
    }
    
    alias get_!'x' x; /// static properties to access the values.
    alias set_!'x' x; 
    alias get_!'y' y; /// ditto
    alias set_!'y' y; 
    alias x s; /// ditto
    alias y t; /// ditto
    alias x r; /// ditto
    alias y g; /// ditto
    static if(dimension >= 3) {
        alias get_!'z' z; /// ditto
        alias set_!'z' z;
        alias z b; /// ditto
        alias z p; /// ditto
    }
    static if(dimension >= 4) {
        alias get_!'w' w; /// ditto
        alias set_!'w' w;
        alias w a; /// ditto
        alias w q; /// ditto
    }
   
    static void isCompatibleVectorImpl(int d)(Vector!(vt, d) vec) if(d <= dimension) {
    }

    template isCompatibleVector(T) {
        enum isCompatibleVector = is(typeof(isCompatibleVectorImpl(T.init)));
    }

    static void isCompatibleMatrixImpl(int r, int c)(Matrix!(vt, r, c) m) {
    }

    template isCompatibleMatrix(T) {
        enum isCompatibleMatrix = is(typeof(isCompatibleMatrixImpl(T.init)));
    }
    
    private void construct(int i, T, Tail...)(T head, Tail tail) {
        static if(i >= dimension) {
            static assert(false, "constructor has too many arguments");
        } else static if(is(T : vt)) {
            vector[i] = head;
            construct!(i + 1)(tail);
        } else static if(isDynamicArray!T) {
            static assert((Tail.length == 0) && (i == 0), "dynamic array can not be passed together with other arguments");
            vector = head;
        } else static if(isStaticArray!T) {
            vector[i .. i + T.length] = head;
            construct!(i + T.length)(tail);
        } else static if(isCompatibleVector!T) {   
            vector[i .. i + T.dimension] = head.vector;
            construct!(i + T.dimension)(tail);
        } else {
            static assert(false, "Vector constructor argument must be of type " ~ vt.stringof ~ " or Vector, not " ~ T.stringof);
        }
    }
    
    private void construct(int i)() { // terminate
    }
    
    /// Constructs the vector.
    /// If a single value is passed the vector, the vector will be cleared with this value.
    /// If a vector with a higher dimension is passed the vector will hold the first values up to its dimension.
    /// If mixed types are passed they will be joined together (allowed types: vector, static array, $(I vt)).
    /// Examples:
    /// ---
    /// vec4 v4 = vec4(1.0f, vec2(2.0f, 3.0f), 4.0f);
    /// vec3 v3 = vec3(v4); // v3 = vec3(1.0f, 2.0f, 3.0f);
    /// vec2 v2 = v3.xy; // swizzling returns a static array.
    /// vec3 v3_2 = vec3(1.0f); // vec3 v3_2 = vec3(1.0f, 1.0f, 1.0f);
    /// ---
    this(Args...)(Args args) {
        construct!(0)(args);
    }
    
    /// ditto
    this(T)(T vec) if(is_vector!T && (T.dimension >= dimension)) {
        vector = vec.vector[0..dimension];
    }
   
    /// ditto
    this()(vt value) {
        clear(value);
    }
    
    static Vector!(float, 2) fromString(string value) {
      //import std.stdio;
      //write(value ~ " -> ");
      
      if (value[0] == '[' && value[$-1] == ']')
        value = value[1..$-1].replace(",", " ");
      
      //writeln(value);
      auto values = value.split(" ");
      
      return vec2(array(map!(to!float)(values[0..2])));
    }
    
    static Vector!(float, 2) fromAngle(float angle) {
      return vec2(sin(angle), cos(angle));
    }
	
    @property float angle() {
      return atan2(cast(float)x, cast(float)y);
    }
    
    unittest {
      assert(vec2d.fromString("1.0 2.0") == vec2d(1.0, 2.0));

      for (float angle = -PI*2; angle < PI*2; angle += 0.1) {
        float calculatedAngle = vec2d.fromAngle(angle).angle;
        float expectedAngle = angle;
        
        while (expectedAngle > PI)
          expectedAngle -= PI*2.0;
        while (expectedAngle < -PI)
          expectedAngle += PI*2.0;

        if (approxEqual(calculatedAngle, PI))
          calculatedAngle -= PI*2.0;
        if (approxEqual(calculatedAngle, -PI))
          calculatedAngle += PI*2.0;
          
        assert(approxEqual(calculatedAngle, expectedAngle), "Calculated angle " ~ to!string(calculatedAngle) ~ " did not match expected angle " ~ to!string(expectedAngle));
      }
    }
          
    /// Returns true if all values are not nan and finite, otherwise false.
    @property bool ok() const {
        foreach(v; vector) {
            if(isNaN(v) || isInfinity(v)) {
                return false;
            }
        }
        return true;
    }
    
    /// Sets all values of the vector to value.
    void clear(vt value) {
        foreach(ref v; vector) {
            v = value;
        }
    }

    unittest {
        vec3 vec_clear;
        assert(!vec_clear.ok);
        vec_clear.clear(1.0f);
        assert(vec_clear.ok);
        assert(vec_clear.vector == [1.0f, 1.0f, 1.0f]);
        assert(vec_clear.vector == vec3(1.0f).vector);
        vec_clear.clear(float.infinity);
        assert(!vec_clear.ok);
        vec_clear.clear(float.nan);
        assert(!vec_clear.ok);
        vec_clear.clear(1.0f);
        assert(vec_clear.ok);
        
        vec4 b = vec4(1.0f, vec_clear);
        assert(b.ok);
        assert(b.vector == [1.0f, 1.0f, 1.0f, 1.0f]);
        assert(b.vector == vec4(1.0f).vector);

        vec2 v2_1 = vec2(vec2(0.0f, 1.0f));
        assert(v2_1.vector == [0.0f, 1.0f]);
        
        vec2 v2_2 = vec2(1.0f, 1.0f);
        assert(v2_2.vector == [1.0f, 1.0f]);
        
        vec3 v3 = vec3(v2_1, 2.0f);
        assert(v3.vector == [0.0f, 1.0f, 2.0f]);
        
        vec4 v4_1 = vec4(1.0f, vec2(2.0f, 3.0f), 4.0f);
        assert(v4_1.vector == [1.0f, 2.0f, 3.0f, 4.0f]);
        assert(vec3(v4_1).vector == [1.0f, 2.0f, 3.0f]);
        assert(vec2(vec3(v4_1)).vector == [1.0f, 2.0f]);
        assert(vec2(vec3(v4_1)).vector == vec2(v4_1).vector);
        assert(v4_1.vector == vec4([1.0f, 2.0f, 3.0f, 4.0f]).vector);
        
        vec4 v4_2 = vec4(vec2(1.0f, 2.0f), vec2(3.0f, 4.0f));
        assert(v4_2.vector == [1.0f, 2.0f, 3.0f, 4.0f]);
        assert(vec3(v4_2).vector == [1.0f, 2.0f, 3.0f]);
        assert(vec2(vec3(v4_2)).vector == [1.0f, 2.0f]);
        assert(vec2(vec3(v4_2)).vector == vec2(v4_2).vector);
        assert(v4_2.vector == vec4([1.0f, 2.0f, 3.0f, 4.0f]).vector);
        
        float[2] f2 = [1.0f, 2.0f];
        float[3] f3 = [1.0f, 2.0f, 3.0f];
        float[4] f4 = [1.0f, 2.0f, 3.0f, 4.0f];
        assert(vec2(1.0f, 2.0f).vector == vec2(f2).vector);
        assert(vec3(1.0f, 2.0f, 3.0f).vector == vec3(f3).vector);
        assert(vec3(1.0f, 2.0f, 3.0f).vector == vec3(f2, 3.0f).vector);
        assert(vec4(1.0f, 2.0f, 3.0f, 4.0f).vector == vec4(f4).vector);
        assert(vec4(1.0f, 2.0f, 3.0f, 4.0f).vector == vec4(f3, 4.0f).vector);
        assert(vec4(1.0f, 2.0f, 3.0f, 4.0f).vector == vec4(f2, 3.0f, 4.0f).vector);
        // useful for: "vec4 v4 = […]" or "vec4 v4 = other_vector.rgba"
    }

    template coord_to_index(char c) {   
        static if((c == 'x') || (c == 'r') || (c == 's')) {
            enum coord_to_index = 0;
        } else static if((c == 'y') || (c == 'g') || (c == 't')) {
            enum coord_to_index = 1;
        } else static if((c == 'z') || (c == 'b') || (c == 'p')) {
            static assert(dimension >= 3, "the " ~ c ~ " property is only available on vectors with a third dimension.");
            enum coord_to_index = 2;
        } else static if((c == 'w') || (c == 'a') || (c == 'q')) {
            static assert(dimension >= 4, "the " ~ c ~ " property is only available on vectors with a fourth dimension.");
            enum coord_to_index = 3;
        } else {
            static assert(false, "accepted coordinates are x, s, r, y, g, t, z, p, b, w, q and a not " ~ c ~ ".");
        }
    }
    
    static if(dimension == 2) { void set(vt x, vt y) { vector[0] = x; vector[1] = y; } }
    static if(dimension == 3) { void set(vt x, vt y, vt z) { vector[0] = x; vector[1] = y; vector[2] = z; } }
    static if(dimension == 4) { void set(vt x, vt y, vt z, vt w) { vector[0] = x; vector[1] = y; vector[2] = z; vector[3] = w; } }
    
    /// Updates the vector with the values from other.
    void update(Vector!(vt, dimension) other) {
        vector = other.vector;
    }

    unittest {
        vec2 v2 = vec2(1.0f, 2.0f);
        assert(v2.x == 1.0f);
        assert(v2.y == 2.0f);
        v2.x = 3.0f;
        assert(v2.vector == [3.0f, 2.0f]);
        v2.y = 4.0f;
        assert(v2.vector == [3.0f, 4.0f]);
        assert((v2.x == 3.0f) && (v2.x == v2.s) && (v2.x == v2.r));
        assert(v2.y == 4.0f);
        assert((v2.y == 4.0f) && (v2.y == v2.t) && (v2.y == v2.g));
        v2.set(0.0f, 1.0f);
        assert(v2.vector == [0.0f, 1.0f]);
        v2.update(vec2(3.0f, 4.0f));
        assert(v2.vector == [3.0f, 4.0f]);
        
        vec3 v3 = vec3(1.0f, 2.0f, 3.0f);
        assert(v3.x == 1.0f);
        assert(v3.y == 2.0f);
        assert(v3.z == 3.0f);
        v3.x = 3.0f;
        assert(v3.vector == [3.0f, 2.0f, 3.0f]);
        v3.y = 4.0f;
        assert(v3.vector == [3.0f, 4.0f, 3.0f]);
        v3.z = 5.0f;
        assert(v3.vector == [3.0f, 4.0f, 5.0f]);
        assert((v3.x == 3.0f) && (v3.x == v3.s) && (v3.x == v3.r));
        assert((v3.y == 4.0f) && (v3.y == v3.t) && (v3.y == v3.g));
        assert((v3.z == 5.0f) && (v3.z == v3.p) && (v3.z == v3.b));
        v3.set(0.0f, 1.0f, 2.0f);
        assert(v3.vector == [0.0f, 1.0f, 2.0f]);
        v3.update(vec3(3.0f, 4.0f, 5.0f));
        assert(v3.vector == [3.0f, 4.0f, 5.0f]);
                
        vec4 v4 = vec4(1.0f, 2.0f, vec2(3.0f, 4.0f));
        assert(v4.x == 1.0f);
        assert(v4.y == 2.0f);
        assert(v4.z == 3.0f);
        assert(v4.w == 4.0f);
        v4.x = 3.0f;
        assert(v4.vector == [3.0f, 2.0f, 3.0f, 4.0f]);
        v4.y = 4.0f;
        assert(v4.vector == [3.0f, 4.0f, 3.0f, 4.0f]);
        v4.z = 5.0f;
        assert(v4.vector == [3.0f, 4.0f, 5.0f, 4.0f]);
        v4.w = 6.0f;
        assert(v4.vector == [3.0f, 4.0f, 5.0f, 6.0f]);
        assert((v4.x == 3.0f) && (v4.x == v4.s) && (v4.x == v4.r));
        assert((v4.y == 4.0f) && (v4.y == v4.t) && (v4.y == v4.g));
        assert((v4.z == 5.0f) && (v4.z == v4.p) && (v4.z == v4.b));
        assert((v4.w == 6.0f) && (v4.w == v4.q) && (v4.w == v4.a));
        v4.set(0.0f, 1.0f, 2.0f, 3.0f);
        assert(v4.vector == [0.0f, 1.0f, 2.0f, 3.0f]);
        v4.update(vec4(3.0f, 4.0f, 5.0f, 6.0f));
        assert(v4.vector == [3.0f, 4.0f, 5.0f, 6.0f]);
    }
    
    /// Returns the current vector formatted as string, useful for printing the vector.
    @property string as_string() {
        return format(isFloatingPoint!(vt) ? "%f":"%s", vector);
    }
    alias as_string toString; /// ditto
    
    void dispatchImpl(int i, string s, int size)(ref vt[size] result) {
        static if(s.length > 0) {
            result[i] = vector[coord_to_index!(s[0])];
            dispatchImpl!(i + 1, s[1..$])(result);
        }
    }

    /// Implements dynamic swizzling.
    /// Returns: a static array of coordinates.
    vt[s.length] opDispatch(string s)() {
        vt[s.length] ret;
        dispatchImpl!(0, s)(ret);
        return ret;
    }
    
    unittest {
        vec2 v2 = vec2(1.0f, 2.0f);
        assert(v2.xytsy == [1.0f, 2.0f, 2.0f, 1.0f, 2.0f]);

        assert(vec3(1.0f, 2.0f, 3.0f).xybzyr == [1.0f, 2.0f, 3.0f, 3.0f, 2.0f, 1.0f]);
        assert(vec4(v2, 3.0f, 4.0f).xyzwrgbastpq == [1.0f, 2.0f, 3.0f, 4.0f,
                                                     1.0f, 2.0f, 3.0f, 4.0f,
                                                     1.0f, 2.0f, 3.0f, 4.0f]);
        assert(vec4(v2, 3.0f, 4.0f).wgyzax == [4.0f, 2.0f, 2.0f, 3.0f, 4.0f, 1.0f]);
        assert(vec4(v2.xyst).vector == [1.0f, 2.0f, 1.0f, 2.0f]);
    }
    
    /// Returns the squared magnitude of the vector.
    @property real magnitude_squared() {
        real temp = 0;
        
        foreach(v; vector) {
            temp += v^^2;
        }
        
        return temp;
    }
    
    /// Returns the magnitude of the vector.
    @property real magnitude() {
        return sqrt(magnitude_squared);
    }
    
    alias magnitude_squared length_squared; /// ditto
    alias magnitude length; /// ditto
    
    /// Normalizes the vector.
    void normalize() {
        real len = length;
        
        if(len != 0) {
            vector[0] /= len;
            vector[1] /= len;
            static if(dimension >= 3) { vector[2] /= len; }
            static if(dimension >= 4) { vector[3] /= len; }
        }
    }
    
    /// Returns a normalized copy of the current vector.
    @property Vector normalized() {
        Vector ret;
        ret.update(this);
        ret.normalize();
        return ret;
    }
    
    Vector opUnary(string op : "-")() {
        Vector ret;
        
        ret.vector[0] = -vector[0];
        ret.vector[1] = -vector[1];
        static if(dimension >= 3) { ret.vector[2] = -vector[2]; }
        static if(dimension >= 4) { ret.vector[3] = -vector[3]; }
        
        return ret;
    }
    
    unittest {
        assert(vec2(1.0f, 1.0f) == -vec2(-1.0f, -1.0f));
        assert(vec2(-1.0f, 1.0f) == -vec2(1.0f, -1.0f));

        assert(-vec3(1.0f, 1.0f, 1.0f) == vec3(-1.0f, -1.0f, -1.0f));
        assert(-vec3(-1.0f, 1.0f, -1.0f) == vec3(1.0f, -1.0f, 1.0f));

        assert(vec4(1.0f, 1.0f, 1.0f, 1.0f) == -vec4(-1.0f, -1.0f, -1.0f, -1.0f));
        assert(vec4(-1.0f, 1.0f, -1.0f, 1.0f) == -vec4(1.0f, -1.0f, 1.0f, -1.0f));
    }
    
    // let the math begin!
    Vector opBinary(string op : "*")(vt r) {
        Vector ret;
        
        ret.vector[0] = vector[0] * r;
        ret.vector[1] = vector[1] * r;
        static if(dimension >= 3) { ret.vector[2] = vector[2] * r; }
        static if(dimension >= 4) { ret.vector[3] = vector[3] * r; }
        
        return ret;
    }

    Vector opBinary(string op)(Vector r) if((op == "+") || (op == "-")) {
        Vector ret;
        
        ret.vector[0] = mixin("vector[0]" ~ op ~ "r.vector[0]");
        ret.vector[1] = mixin("vector[1]" ~ op ~ "r.vector[1]");
        static if(dimension >= 3) { ret.vector[2] = mixin("vector[2]" ~ op ~ "r.vector[2]"); }
        static if(dimension >= 4) { ret.vector[3] = mixin("vector[3]" ~ op ~ "r.vector[3]"); }
        
        return ret;
    }
    
    vt opBinary(string op : "*")(Vector r) {
        return dot(this, r);
    }

    Vector!(vt, T.rows) opBinary(string op : "*", T)(T inp) if(isCompatibleMatrix!T && (T.cols == dimension)) {
        Vector!(vt, T.rows) ret;
        ret.clear(0);
        
        for(int r = 0; r < inp.rows; r++) {
            for(int c = 0; c < inp.cols; c++) {
                ret.vector[r] += vector[c] * inp.matrix[r][c];
            }
        }
        
        return ret;
    }
    
    auto opBinaryRight(string op, T)(T inp) if(!is_vector!T && !is_matrix!T && !is_quaternion!T) {
        return this.opBinary!(op)(inp);
    }

    unittest {
        vec2 v2 = vec2(1.0f, 3.0f);
        2 * v2;
        assert((v2*2.5f).vector == [2.5f, 7.5f]);
        assert((v2+vec2(3.0f, 1.0f)).vector == [4.0f, 4.0f]);
        assert((v2-vec2(1.0f, 3.0f)).vector == [0.0f, 0.0f]);
        assert((v2*vec2(2.0f, 2.0f)) == 8.0f);

        vec3 v3 = vec3(1.0f, 3.0f, 5.0f);
        assert((v3*2.5f).vector == [2.5f, 7.5f, 12.5f]);
        assert((v3+vec3(3.0f, 1.0f, -1.0f)).vector == [4.0f, 4.0f, 4.0f]);
        assert((v3-vec3(1.0f, 3.0f, 5.0f)).vector == [0.0f, 0.0f, 0.0f]);
        assert((v3*vec3(2.0f, 2.0f, 2.0f)) == 18.0f);
        
        vec4 v4 = vec4(1.0f, 3.0f, 5.0f, 7.0f);
        assert((v4*2.5f).vector == [2.5f, 7.5f, 12.5f, 17.5]);
        assert((v4+vec4(3.0f, 1.0f, -1.0f, -3.0f)).vector == [4.0f, 4.0f, 4.0f, 4.0f]);
        assert((v4-vec4(1.0f, 3.0f, 5.0f, 7.0f)).vector == [0.0f, 0.0f, 0.0f, 0.0f]);
        assert((v4*vec4(2.0f, 2.0f, 2.0f, 2.0f)) == 32.0f);

        mat2 m2 = mat2(1.0f, 2.0f, 3.0f, 4.0f);
        vec2 v2_2 = vec2(2.0f, 2.0f);
        assert((v2_2*m2).vector == [6.0f, 14.0f]);

        mat3 m3 = mat3(1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f);
        vec3 v3_2 = vec3(2.0f, 2.0f, 2.0f);
        assert((v3_2*m3).vector == [12.0f, 30.0f, 48.0f]);
    }
    
    void opOpAssign(string op : "*")(vt r) {
        vector[0] *= r;
        vector[1] *= r;
        static if(dimension >= 3) { vector[2] *= r; }
        static if(dimension >= 4) { vector[3] *= r; }
    }

    void opOpAssign(string op)(Vector r) if((op == "+") || (op == "-")) {
        mixin("vector[0]" ~ op ~ "= r.vector[0];");
        mixin("vector[1]" ~ op ~ "= r.vector[1];");
        static if(dimension >= 3) { mixin("vector[2]" ~ op ~ "= r.vector[2];"); }
        static if(dimension >= 4) { mixin("vector[3]" ~ op ~ "= r.vector[3];"); }
    }
        
    unittest {
        vec2 v2 = vec2(1.0f, 3.0f);
        v2 *= 2.5f;
        assert(v2.vector == [2.5f, 7.5f]);
        v2 -= vec2(2.5f, 7.5f);
        assert(v2.vector == [0.0f, 0.0f]);
        v2 += vec2(1.0f, 3.0f);
        assert(v2.vector == [1.0f, 3.0f]);
        assert(v2.length == sqrt(10.0));
        assert(v2.length_squared == 10);
        assert((v2.magnitude == v2.length) && (v2.magnitude_squared == v2.length_squared));
        assert(v2.normalized == vec2(1.0f/sqrt(10.0), 3.0f/sqrt(10.0)));

        vec3 v3 = vec3(1.0f, 3.0f, 5.0f);
        v3 *= 2.5f;
        assert(v3.vector == [2.5f, 7.5f, 12.5f]);
        v3 -= vec3(2.5f, 7.5f, 12.5f);
        assert(v3.vector == [0.0f, 0.0f, 0.0f]);
        v3 += vec3(1.0f, 3.0f, 5.0f);
        assert(v3.vector == [1.0f, 3.0f, 5.0f]);
        assert(v3.length == sqrt(35.0));
        assert(v3.length_squared == 35);
        assert((v3.magnitude == v3.length) && (v3.magnitude_squared == v3.length_squared));
        assert(v3.normalized == vec3(1.0f/sqrt(35.0), 3.0f/sqrt(35.0), 5.0f/sqrt(35.0)));
            
        vec4 v4 = vec4(1.0f, 3.0f, 5.0f, 7.0f);
        v4 *= 2.5f;
        assert(v4.vector == [2.5f, 7.5f, 12.5f, 17.5]);
        v4 -= vec4(2.5f, 7.5f, 12.5f, 17.5f);
        assert(v4.vector == [0.0f, 0.0f, 0.0f, 0.0f]);
        v4 += vec4(1.0f, 3.0f, 5.0f, 7.0f);
        assert(v4.vector == [1.0f, 3.0f, 5.0f, 7.0f]);
        assert(v4.length == sqrt(84.0));
        assert(v4.length_squared == 84);
        assert((v4.magnitude == v4.length) && (v4.magnitude_squared == v4.length_squared));
        assert(v4.normalized == vec4(1.0f/sqrt(84.0), 3.0f/sqrt(84.0), 5.0f/sqrt(84.0), 7.0f/sqrt(84.0)));
    }
       
    const bool opEquals(T)(T vec) if(T.dimension == dimension) {
        return vector == vec.vector;
    }
    
    bool opCast(T : bool)() {
        return ok;
    }
    
    unittest {
        assert(vec2(1.0f, 2.0f) == vec2(1.0f, 2.0f));
        assert(vec2(1.0f, 2.0f) != vec2(1.0f, 1.0f));
        assert(vec2(1.0f, 2.0f) == vec2d(1.0, 2.0));
        assert(vec2(1.0f, 2.0f) != vec2d(1.0, 1.0));
                
        assert(vec3(1.0f, 2.0f, 3.0f) == vec3(1.0f, 2.0f, 3.0f));
        assert(vec3(1.0f, 2.0f, 3.0f) != vec3(1.0f, 2.0f, 2.0f));
        assert(vec3(1.0f, 2.0f, 3.0f) == vec3d(1.0, 2.0, 3.0));
        assert(vec3(1.0f, 2.0f, 3.0f) != vec3d(1.0, 2.0, 2.0));
                
        assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) == vec4(1.0f, 2.0f, 3.0f, 4.0f));
        assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) != vec4(1.0f, 2.0f, 3.0f, 3.0f));
        assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) == vec4d(1.0, 2.0, 3.0, 4.0));
        assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) != vec4d(1.0, 2.0, 3.0, 3.0));
    
        assert(!(vec4(float.nan)));
        if(vec4(1.0f)) { }
        else { assert(false); }
    }
        
}

/// Calculates the dot product between two vectors.
T.vt dot(T)(T veca, T vecb) if(is_vector!T) {
    T.vt temp = 0;
    
    temp += veca.vector[0] * vecb.vector[0];
    temp += veca.vector[1] * vecb.vector[1];
    static if(T.dimension >= 3) { temp += veca.vector[2] * vecb.vector[2]; }
    static if(T.dimension >= 4) { temp += veca.vector[3] * vecb.vector[3]; }
            
    return temp;
}

/// Calculates the cross product of tow 3-dimensional vectors.
T cross(T)(T veca, T vecb) if(is_vector!T && (T.dimension == 3)) {
   return T(veca.y * vecb.z - vecb.y * veca.z,
            veca.z * vecb.x - vecb.z * veca.x,
            veca.x * vecb.y - vecb.x * veca.y);
}

/// Calculates the distance between two  vectors.
T.vt distance(T)(T veca, T vecb) if(is_vector!T) {
    return (veca - vecb).length;
}

unittest {
    // dot is already tested in Vector.opBinary, so no need for testing with more vectors
    vec3 v1 = vec3(1.0f, 2.0f, -3.0f);
    vec3 v2 = vec3(1.0f, 3.0f, 2.0f);
    
    assert(dot(v1, v2) == 1.0f);
    assert(dot(v1, v2) == (v1 * v2));
    assert(dot(v1, v2) == dot(v2, v1));
    assert((v1 * v2) == (v1 * v2));
    
    assert(cross(v1, v2).vector == [13.0f, -5.0f, 1.0f]);
    assert(cross(v2, v1).vector == [-13.0f, 5.0f, -1.0f]);
    
    assert(distance(vec2(0.0f, 0.0f), vec2(0.0f, 10.0f)) == 10.0);        
}
 
/// Pre-defined vector types, the number represents the dimension and the last letter the type (none = float, d = double, i = int).
alias Vector!(float, 2) vec2; 
alias Vector!(float, 3) vec3; /// ditto
alias Vector!(float, 4) vec4; /// ditto

alias Vector!(double, 2) vec2d; /// ditto
alias Vector!(double, 3) vec3d; /// ditto
alias Vector!(double, 4) vec4d; /// ditto

alias Vector!(int, 2) vec2i; /// ditto
alias Vector!(int, 3) vec3i; /// ditto
alias Vector!(int, 4) vec4i; /// ditto

/*alias Vector!(ubyte, 2) vec2ub;
alias Vector!(ubyte, 3) vec3ub;
alias Vector!(ubyte, 4) vec4ub;*/


/// Base template for all matrix-types.
/// Params:
///  type = all values get stored as this type
///  rows_ = rows of the matrix
///  cols_ = columns of the matrix
/// Examples:
/// ---
/// alias Matrix!(float, 4, 4) mat4;
/// alias Matrix!(double, 3, 4) mat34d;
/// alias Matrix!(real, 2, 2) mat2r;
/// ---
struct Matrix(type, int rows_, int cols_) if((rows_ > 0) && (cols_ > 0)) {
    alias type mt; /// Holds the internal type of the matrix;
    static const int rows = rows_; /// Holds the number of rows;
    static const int cols = cols_; /// Holds the number of columns;
    
    /// Holds the matrix $(RED row-major) in memory.
    mt[cols][rows] matrix; // In C it would be mt[rows][cols], D does it like this: (mt[foo])[bar]
    alias matrix this;
    
    unittest {
        mat2 m2 = mat2(0.0f, 1.0f, 2.0f, 3.0f);
        assert(m2[0][0] == 0.0f);
        assert(m2[0][1] == 1.0f);
        assert(m2[1][0] == 2.0f);
        assert(m2[1][1] == 3.0f);
        m2[0..1] = [2.0f, 2.0f];
        assert(m2 == [[2.0f, 2.0f], [2.0f, 3.0f]]);
        
        mat3 m3 = mat3(0.0f, 0.1f, 0.2f, 1.0f, 1.1f, 1.2f, 2.0f, 2.1f, 2.2f);
        assert(m3[0][1] == 0.1f);
        assert(m3[2][0] == 2.0f);
        assert(m3[1][2] == 1.2f);
        m3[0][0..$] = 0.0f;
        assert(m3 == [[0.0f, 0.0f, 0.0f],
                      [1.0f, 1.1f, 1.2f],
                      [2.0f, 2.1f, 2.2f]]);
        
        mat4 m4 = mat4(0.0f, 0.1f, 0.2f, 0.3f,
                       1.0f, 1.1f, 1.2f, 1.3f,
                       2.0f, 2.1f, 2.2f, 2.3f,
                       3.0f, 3.1f, 3.2f, 3.3f);
       assert(m4[0][3] == 0.3f);
       assert(m4[1][1] == 1.1f);
       assert(m4[2][0] == 2.0f);
       assert(m4[3][2] == 3.2f);
       m4[2][1..3] = [1.0f, 2.0f];
       assert(m4 == [[0.0f, 0.1f, 0.2f, 0.3f],
                     [1.0f, 1.1f, 1.2f, 1.3f],
                     [2.0f, 1.0f, 2.0f, 2.3f],
                     [3.0f, 3.1f, 3.2f, 3.3f]]);
       
    }
    
    /// Returns the pointer to the stored values as OpenGL requires it.
    /// Note this will return a pointer to a $(RED row-major) matrix, 
    /// this means you've to set the transpose argument to GL_TRUE when passing it to OpenGL.
    @property auto value_ptr() { return matrix[0].ptr; }
    
    static void isCompatibleMatrixImpl(int r, int c)(Matrix!(mt, r, c) m) {
    }

    template isCompatibleMatrix(T) {
        enum isCompatibleMatrix = is(typeof(isCompatibleMatrixImpl(T.init)));
    }
    
    static void isCompatibleVectorImpl(int d)(Vector!(mt, d) vec) {
    }

    template isCompatibleVector(T) {
        enum isCompatibleVector = is(typeof(isCompatibleVectorImpl(T.init)));
    }
        
    private void construct(int i, T, Tail...)(T head, Tail tail) {
        static if(i >= rows*cols) {
            static assert(false, "constructor has too many arguments");
        } else static if(is(T : mt)) {
            matrix[i / cols][i % cols] = head;
            construct!(i + 1)(tail);
        } else static if(is(T == Vector!(mt, cols))) {
            static if(i % cols == 0) {
                matrix[i / cols] = head.vector;
                construct!(i + T.dimension)(tail);
            } else {
                static assert(false, "Can't convert Vector into the matrix. Maybe it doesn't align to the columns correctly or dimension doesn't fit");
            }
        } else {
            static assert(false, "Matrix constructor argument must be of type " ~ mt.stringof ~ " or Vector, not " ~ T.stringof);
        }
    }
    
    private void construct(int i)() { // terminate
    }
    
    /// Constructs the matrix:
    /// If a single value is passed, the matrix will be cleared with this value (each column in each row will contain this value).
    /// If a matrix with more rows and columns is passed, the matrix will be the upper left nxm matrix.
    /// If a matrix with less rows and columns is passed, the passed matrix will be stored in the upper left of an identity matrix.
    /// It's also allowed to pass vectors and scalars at a time, but the vectors dimension must match the number of columns and align correctly.
    /// Examples:
    /// ---
    /// mat2 m2 = mat2(0.0f); // mat2 m2 = mat2(0.0f, 0.0f, 0.0f, 0.0f);
    /// mat3 m3 = mat3(m2); // mat3 m3 = mat3(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
    /// mat3 m3_2 = mat3(vec3(1.0f, 2.0f, 3.0f,), 4.0f, 5.0f, 6.0f, vec3(7.0f, 8.0f, 9.0f));
    /// mat4 m4 = mat4.identity // just an identity matrix
    /// mat3 m3_3 = mat3(m4) // mat3 m3_3 = mat3.identity
    /// ---
    this(Args...)(Args args) {
        construct!(0)(args);
    }
    
    /// ditto
    this(T)(T mat) if(is_matrix!T && (T.cols >= cols) && (T.rows >= rows)) {
        for(int r = 0; r < rows; r++) {
            for(int c = 0; c < cols; c++) {
                matrix[r][c] = mat.matrix[r][c];
            }
        }
    }
    
    /// ditto
    this(T)(T mat) if(is_matrix!T && (T.cols < cols) && (T.rows < rows)) {
        make_identity();
        for(int r = 0; r < T.rows; r++) {
            for(int c = 0; c < T.cols; c++) {
                matrix[r][c] = mat.matrix[r][c];
            }
        }
    }
    
    /// ditto
    this()(mt value) {
        clear(value);
    }
    
    /// Returns true if all values are not nan and finite, otherwise false.
    @property bool ok() {
        foreach(row; matrix) {
            foreach(col; row) {
                if(isNaN(col) || isInfinity(col)) {
                    return false;
                }
            }
        }
        return true;
    }
    
    /// Sets all values of the matrix to value (each column in each row will contain this value).
    void clear(mt value) {
        for(int r = 0; r < rows; r++) {
            for(int c = 0; c < cols; c++) {
                matrix[r][c] = value;
            }
        }
    }
    
    unittest {
        mat2 m2 = mat2(1.0f, 1.0f, vec2(2.0f, 2.0f));
        assert(m2.matrix == [[1.0f, 1.0f], [2.0f, 2.0f]]);
        m2.clear(3.0f);
        assert(m2.matrix == [[3.0f, 3.0f], [3.0f, 3.0f]]);
        assert(m2.ok);
        m2.clear(float.nan);
        assert(!m2.ok);
        m2.clear(float.infinity);
        assert(!m2.ok);
        m2.clear(0.0f);
        assert(m2.ok);
        
        mat3 m3 = mat3(1.0f);
        assert(m3.matrix == [[1.0f, 1.0f, 1.0f],
                             [1.0f, 1.0f, 1.0f],
                             [1.0f, 1.0f, 1.0f]]);
        
        mat4 m4 = mat4(vec4(1.0f, 1.0f, 1.0f, 1.0f),
                            2.0f, 2.0f, 2.0f, 2.0f,
                            3.0f, 3.0f, 3.0f, 3.0f,
                       vec4(4.0f, 4.0f, 4.0f, 4.0f));
        assert(m4.matrix == [[1.0f, 1.0f, 1.0f, 1.0f],
                             [2.0f, 2.0f, 2.0f, 2.0f],
                             [3.0f, 3.0f, 3.0f, 3.0f],
                             [4.0f, 4.0f, 4.0f, 4.0f]]);
        assert(mat3(m4).matrix == [[1.0f, 1.0f, 1.0f],
                                   [2.0f, 2.0f, 2.0f],
                                   [3.0f, 3.0f, 3.0f]]);
        assert(mat2(mat3(m4)).matrix == [[1.0f, 1.0f], [2.0f, 2.0f]]);
        assert(mat2(m4).matrix == mat2(mat3(m4)).matrix);
        assert(mat4(mat3(m4)).matrix == [[1.0f, 1.0f, 1.0f, 0.0f],
                                         [2.0f, 2.0f, 2.0f, 0.0f],
                                         [3.0f, 3.0f, 3.0f, 0.0f],
                                         [0.0f, 0.0f, 0.0f, 1.0f]]);

        Matrix!(float, 2, 3) mt1 = Matrix!(float, 2, 3)(1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f);
        Matrix!(float, 3, 2) mt2 = Matrix!(float, 3, 2)(6.0f, -1.0f, 3.0f, 2.0f, 0.0f, -3.0f);
        
        assert(mt1.matrix == [[1.0f, 2.0f, 3.0f], [4.0f, 5.0f, 6.0f]]);
        assert(mt2.matrix == [[6.0f, -1.0f], [3.0f, 2.0f], [0.0f, -3.0f]]);
    }
    
    /// Returns the current matrix formatted as flat string.
    @property string as_string() {
        return format(isFloatingPoint!(mt) ? "%f":"%s", matrix);
    }
    alias as_string toString; /// ditto
    
    /// Returns the current matrix as pretty formatted string. 
    @property string as_pretty_string() {
        string fmtr = isFloatingPoint!(mt) ? "%f":"%s";
        
        size_t rjust = max(format(fmtr, reduce!(max)(matrix[])).length,
                           format(fmtr, reduce!(min)(matrix[])).length) - 1;
        
        string[] outer_parts;
        foreach(mt[] row; matrix) {
            string[] inner_parts;
            foreach(mt col; row) {
                inner_parts ~= rightJustify(format(fmtr, col), rjust);
            }
            outer_parts ~= " [" ~ join(inner_parts, ", ") ~ "]";
        }
        
        return "[" ~ join(outer_parts, "\n")[1..$] ~ "]";
    }
    alias as_pretty_string toPrettyString; /// ditto
    
    static if(rows == cols) {
        /// Makes the current matrix an identity matrix.
        void make_identity() {
            clear(0);
            for(int r = 0; r < rows; r++) {
                matrix[r][r] = 1;
            }
        }
        
        /// Returns a identity matrix.
        static @property Matrix identity() {
            Matrix ret;
            ret.clear(0);
            
            for(int r = 0; r < rows; r++) {
                ret.matrix[r][r] = 1;
            }
            
            return ret;
        }
        
        /// Transposes the current matrix;
        void transpose() {
            matrix = transposed().matrix;
        }
        
        unittest {
            mat2 m2 = mat2(1.0f);
            m2.transpose();
            assert(m2.matrix == mat2(1.0f).matrix);
            m2.make_identity();
            assert(m2.matrix == [[1.0f, 0.0f],
                                 [0.0f, 1.0f]]);
            m2.transpose();
            assert(m2.matrix == [[1.0f, 0.0f],
                                 [0.0f, 1.0f]]);
            assert(m2.matrix == m2.identity.matrix);
            
            mat3 m3 = mat3(1.1f, 1.2f, 1.3f,
                           2.1f, 2.2f, 2.3f,
                           3.1f, 3.2f, 3.3f);
            m3.transpose();
            assert(m3.matrix == [[1.1f, 2.1f, 3.1f],
                                 [1.2f, 2.2f, 3.2f],
                                 [1.3f, 2.3f, 3.3f]]);
            
            mat4 m4 = mat4(2.0f);
            m4.transpose();
            assert(m4.matrix == mat4(2.0f).matrix);
            m4.make_identity();
            assert(m4.matrix == [[1.0f, 0.0f, 0.0f, 0.0f],
                                 [0.0f, 1.0f, 0.0f, 0.0f],
                                 [0.0f, 0.0f, 1.0f, 0.0f],
                                 [0.0f, 0.0f, 0.0f, 1.0f]]);
            assert(m4.matrix == m4.identity.matrix);
        }
        
    }
    
    /// Returns a transposed copy of the matrix.
    @property Matrix transposed() {
        Matrix ret;
        
        for(int r = 0; r < rows; r++) {
            for(int c = 0; c < cols; c++) {
                ret.matrix[c][r] = matrix[r][c];
            }
        }
        
        return ret;
    }
    
    // transposed already tested in last unittest
    
    static if((rows == 2) && (cols == 2)) {
        @property mt det() {
            return (matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]);
        }
        
        private Matrix invert(ref Matrix mat) {
            mt d = det;
            
            mat.matrix = [[matrix[1][1]/det, -matrix[0][1]/d],
                          [-matrix[1][0]/det, matrix[0][0]/d]];
            
            return mat;
        }
        
        /// Returns an identity matrix with an applied rotation (nxn matrices, n == 2).
        static Matrix rotation(real alpha) {
            Matrix mult = Matrix.identity;
            
            mt cosamt = to!mt(cos(alpha));
            mt sinamt = to!mt(sin(alpha));
            
            mult.matrix[0][0] = cosamt;
            mult.matrix[0][1] = -sinamt;
            mult.matrix[1][0] = sinamt;
            mult.matrix[1][1] = cosamt;
            
            return mult;
        }
    } else static if((rows == 3) && (cols == 3)) {
        @property mt det() {
            return (matrix[0][0] * matrix[1][1] * matrix[2][2]
                  + matrix[0][1] * matrix[1][2] * matrix[2][0]
                  + matrix[0][2] * matrix[1][0] * matrix[2][1]
                  - matrix[0][2] * matrix[1][1] * matrix[2][0]
                  - matrix[0][1] * matrix[1][0] * matrix[2][2]
                  - matrix[0][0] * matrix[1][2] * matrix[2][1]);
        }
        
        private Matrix invert(ref Matrix mat) {
            mt d = det;
            
            mat.matrix = [[(matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])/d,
                           (matrix[0][2] * matrix[2][1] - matrix[0][1] * matrix[2][2])/d,
                           (matrix[0][1] * matrix[1][2] - matrix[0][2] * matrix[1][1])/d],
                          [(matrix[1][2] * matrix[2][0] - matrix[1][0] * matrix[2][2])/d,
                           (matrix[0][0] * matrix[2][2] - matrix[0][2] * matrix[2][0])/d,
                           (matrix[0][2] * matrix[1][0] - matrix[0][0] * matrix[1][2])/d],
                          [(matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0])/d,
                           (matrix[0][1] * matrix[2][0] - matrix[0][0] * matrix[2][1])/d,
                           (matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0])/d]];
            
            return mat;
        }
        
        static Matrix translation(mt x, mt y) {
           Matrix ret = Matrix.identity;
           
           ret.matrix[0][2] = x;
           ret.matrix[1][2] = y;
           
           return ret;            
        }
        
        Matrix translate(mt x, mt y) {
            this = this * Matrix.translation(x, y);
            return this;
        }
        
        static Matrix scaling(mt x, mt y) {
            Matrix ret = Matrix.identity;
            
            ret.matrix[0][0] = x;
            ret.matrix[1][1] = y;
            
            return ret;
        }

        Matrix scale(mt x, mt y) {
            this = this * Matrix.scaling(x, y);
            return this;
        }

    } else static if((rows == 4) && (cols == 4)) {
        /// Returns the determinant of the current matrix (2x2, 3x3 and 4x4 matrices).
        @property mt det() {
            return (matrix[0][3] * matrix[1][2] * matrix[2][1] * matrix[3][0] - matrix[0][2] * matrix[1][3] * matrix[2][1] * matrix[3][0]
                  - matrix[0][3] * matrix[1][1] * matrix[2][2] * matrix[3][0] + matrix[0][1] * matrix[1][3] * matrix[2][2] * matrix[3][0]
                  + matrix[0][2] * matrix[1][1] * matrix[2][3] * matrix[3][0] - matrix[0][1] * matrix[1][2] * matrix[2][3] * matrix[3][0]
                  - matrix[0][3] * matrix[1][2] * matrix[2][0] * matrix[3][1] + matrix[0][2] * matrix[1][3] * matrix[2][0] * matrix[3][1]
                  + matrix[0][3] * matrix[1][0] * matrix[2][2] * matrix[3][1] - matrix[0][0] * matrix[1][3] * matrix[2][2] * matrix[3][1]
                  - matrix[0][2] * matrix[1][0] * matrix[2][3] * matrix[3][1] + matrix[0][0] * matrix[1][2] * matrix[2][3] * matrix[3][1]
                  + matrix[0][3] * matrix[1][1] * matrix[2][0] * matrix[3][2] - matrix[0][1] * matrix[1][3] * matrix[2][0] * matrix[3][2]
                  - matrix[0][3] * matrix[1][0] * matrix[2][1] * matrix[3][2] + matrix[0][0] * matrix[1][3] * matrix[2][1] * matrix[3][2]
                  + matrix[0][1] * matrix[1][0] * matrix[2][3] * matrix[3][2] - matrix[0][0] * matrix[1][1] * matrix[2][3] * matrix[3][2]
                  - matrix[0][2] * matrix[1][1] * matrix[2][0] * matrix[3][3] + matrix[0][1] * matrix[1][2] * matrix[2][0] * matrix[3][3]
                  + matrix[0][2] * matrix[1][0] * matrix[2][1] * matrix[3][3] - matrix[0][0] * matrix[1][2] * matrix[2][1] * matrix[3][3]
                  - matrix[0][1] * matrix[1][0] * matrix[2][2] * matrix[3][3] + matrix[0][0] * matrix[1][1] * matrix[2][2] * matrix[3][3]);
        }

        private Matrix invert(ref Matrix mat) {
            mt d = det;
            
            mat.matrix = [[(matrix[1][1] * matrix[2][2] * matrix[3][3] + matrix[1][2] * matrix[2][3] * matrix[3][1] + matrix[1][3] * matrix[2][1] * matrix[3][2]
                          - matrix[1][1] * matrix[2][3] * matrix[3][2] - matrix[1][2] * matrix[2][1] * matrix[3][3] - matrix[1][3] * matrix[2][2] * matrix[3][1])/d,
                           (matrix[0][1] * matrix[2][3] * matrix[3][2] + matrix[0][2] * matrix[2][1] * matrix[3][3] + matrix[0][3] * matrix[2][2] * matrix[3][1]
                          - matrix[0][1] * matrix[2][2] * matrix[3][3] - matrix[0][2] * matrix[2][3] * matrix[3][1] - matrix[0][3] * matrix[2][1] * matrix[3][2])/d,
                           (matrix[0][1] * matrix[1][2] * matrix[3][3] + matrix[0][2] * matrix[1][3] * matrix[3][1] + matrix[0][3] * matrix[1][1] * matrix[3][2]
                          - matrix[0][1] * matrix[1][3] * matrix[3][2] - matrix[0][2] * matrix[1][1] * matrix[3][3] - matrix[0][3] * matrix[1][2] * matrix[3][1])/d,
                           (matrix[0][1] * matrix[1][3] * matrix[2][2] + matrix[0][2] * matrix[1][1] * matrix[2][3] + matrix[0][3] * matrix[1][2] * matrix[2][1]
                          - matrix[0][1] * matrix[1][2] * matrix[2][3] - matrix[0][2] * matrix[1][3] * matrix[2][1] - matrix[0][3] * matrix[1][1] * matrix[2][2])/d],
                          [(matrix[1][0] * matrix[2][3] * matrix[3][2] + matrix[1][2] * matrix[2][0] * matrix[3][3] + matrix[1][3] * matrix[2][2] * matrix[3][0]
                          - matrix[1][0] * matrix[2][2] * matrix[3][3] - matrix[1][2] * matrix[2][3] * matrix[3][0] - matrix[1][3] * matrix[2][0] * matrix[3][2])/d,
                           (matrix[0][0] * matrix[2][2] * matrix[3][3] + matrix[0][2] * matrix[2][3] * matrix[3][0] + matrix[0][3] * matrix[2][0] * matrix[3][2]
                          - matrix[0][0] * matrix[2][3] * matrix[3][2] - matrix[0][2] * matrix[2][0] * matrix[3][3] - matrix[0][3] * matrix[2][2] * matrix[3][0])/d,
                           (matrix[0][0] * matrix[1][3] * matrix[3][2] + matrix[0][2] * matrix[1][0] * matrix[3][3] + matrix[0][3] * matrix[1][2] * matrix[3][0]
                          - matrix[0][0] * matrix[1][2] * matrix[3][3] - matrix[0][2] * matrix[1][3] * matrix[3][0] - matrix[0][3] * matrix[1][0] * matrix[3][2])/d,
                           (matrix[0][0] * matrix[1][2] * matrix[2][3] + matrix[0][2] * matrix[1][3] * matrix[2][0] + matrix[0][3] * matrix[1][0] * matrix[2][2]
                          - matrix[0][0] * matrix[1][3] * matrix[2][2] - matrix[0][2] * matrix[1][0] * matrix[2][3] - matrix[0][3] * matrix[1][2] * matrix[2][0])/d],
                          [(matrix[1][0] * matrix[2][1] * matrix[3][3] + matrix[1][1] * matrix[2][3] * matrix[3][0] + matrix[1][3] * matrix[2][0] * matrix[3][1]
                          - matrix[1][0] * matrix[2][3] * matrix[3][1] - matrix[1][1] * matrix[2][0] * matrix[3][3] - matrix[1][3] * matrix[2][1] * matrix[3][0])/d,
                           (matrix[0][0] * matrix[2][3] * matrix[3][1] + matrix[0][1] * matrix[2][0] * matrix[3][3] + matrix[0][3] * matrix[2][1] * matrix[3][0]
                          - matrix[0][0] * matrix[2][1] * matrix[3][3] - matrix[0][1] * matrix[2][3] * matrix[3][0] - matrix[0][3] * matrix[2][0] * matrix[3][1])/d,
                           (matrix[0][0] * matrix[1][1] * matrix[3][3] + matrix[0][1] * matrix[1][3] * matrix[3][0] + matrix[0][3] * matrix[1][0] * matrix[3][1]
                          - matrix[0][0] * matrix[1][3] * matrix[3][1] - matrix[0][1] * matrix[1][0] * matrix[3][3] - matrix[0][3] * matrix[1][1] * matrix[3][0])/d,
                           (matrix[0][0] * matrix[1][3] * matrix[2][1] + matrix[0][1] * matrix[1][0] * matrix[2][3] + matrix[0][3] * matrix[1][1] * matrix[2][0]
                          - matrix[0][0] * matrix[1][1] * matrix[2][3] - matrix[0][1] * matrix[1][3] * matrix[2][0] - matrix[0][3] * matrix[1][0] * matrix[2][1])/d],
                          [(matrix[1][0] * matrix[2][2] * matrix[3][1] + matrix[1][1] * matrix[2][0] * matrix[3][2] + matrix[1][2] * matrix[2][1] * matrix[3][0]
                          - matrix[1][0] * matrix[2][1] * matrix[3][2] - matrix[1][1] * matrix[2][2] * matrix[3][0] - matrix[1][2] * matrix[2][0] * matrix[3][1])/d,
                           (matrix[0][0] * matrix[2][1] * matrix[3][2] + matrix[0][1] * matrix[2][2] * matrix[3][0] + matrix[0][2] * matrix[2][0] * matrix[3][1]
                          - matrix[0][0] * matrix[2][2] * matrix[3][1] - matrix[0][1] * matrix[2][0] * matrix[3][2] - matrix[0][2] * matrix[2][1] * matrix[3][0])/d,
                           (matrix[0][0] * matrix[1][2] * matrix[3][1] + matrix[0][1] * matrix[1][0] * matrix[3][2] + matrix[0][2] * matrix[1][1] * matrix[3][0]
                          - matrix[0][0] * matrix[1][1] * matrix[3][2] - matrix[0][1] * matrix[1][2] * matrix[3][0] - matrix[0][2] * matrix[1][0] * matrix[3][1])/d,
                           (matrix[0][0] * matrix[1][1] * matrix[2][2] + matrix[0][1] * matrix[1][2] * matrix[2][0] + matrix[0][2] * matrix[1][0] * matrix[2][1]
                          - matrix[0][0] * matrix[1][2] * matrix[2][1] - matrix[0][1] * matrix[1][0] * matrix[2][2] - matrix[0][2] * matrix[1][1] * matrix[2][0])/d]];
                  
            return mat;
        }
        
        // some static fun ...
        // (1) glprogramming.com/red/appendixf.html - ortographic is broken!
        // (2) http://fly.cc.fer.hr/~unreal/theredbook/appendixg.html
        // (3) http://en.wikipedia.org/wiki/Orthographic_projection_(geometry)
        
        /// Returns a translation matrix (3x3 and 4x4 matrices).
        static Matrix translation(mt x, mt y, mt z) {
           Matrix ret = Matrix.identity;
           
           ret.matrix[0][3] = x;
           ret.matrix[1][3] = y;
           ret.matrix[2][3] = z;
           
           return ret;            
        }
        
        /// Applys a translation on the current matrix and returns $(I this) (3x3 and 4x4 matrices).
        Matrix translate(mt x, mt y, mt z) {
            this = this * Matrix.translation(x, y, z);
            return this;
        }
        
        /// Returns a scaling matrix (3x3 and 4x4 matrices);
        static Matrix scaling(mt x, mt y, mt z) {
            Matrix ret = Matrix.identity;

            ret.matrix[0][0] = x;
            ret.matrix[1][1] = y;
            ret.matrix[2][2] = z;
            
            return ret;
        }
        
        /// Applys a scale to the current matrix and returns $(I this) (3x3 and 4x4 matrices).
        Matrix scale(mt x, mt y, mt z) {
            this = this * Matrix.scaling(x, y, z);
            return this;
        }
              
        unittest {
            mat4 m4 = mat4(1.0f);
            assert(m4.translation(1.0f, 2.0f, 3.0f).matrix == mat4.translation(1.0f, 2.0f, 3.0f).matrix);
            assert(mat4.translation(1.0f, 2.0f, 3.0f).matrix == [[1.0f, 0.0f, 0.0f, 1.0f],
                                                               [0.0f, 1.0f, 0.0f, 2.0f],
                                                               [0.0f, 0.0f, 1.0f, 3.0f],
                                                               [0.0f, 0.0f, 0.0f, 1.0f]]);
            assert(mat4.identity.translate(0.0f, 1.0f, 2.0f).matrix == mat4.translation(0.0f, 1.0f, 2.0f).matrix);
            
            assert(m4.scaling(0.0f, 1.0f, 2.0f).matrix == mat4.scaling(0.0f, 1.0f, 2.0f).matrix);
            assert(mat4.scaling(0.0f, 1.0f, 2.0f).matrix == [[0.0f, 0.0f, 0.0f, 0.0f],
                                                           [0.0f, 1.0f, 0.0f, 0.0f],
                                                           [0.0f, 0.0f, 2.0f, 0.0f],
                                                           [0.0f, 0.0f, 0.0f, 1.0f]]);
            assert(mat4.identity.scale(0.0f, 1.0f, 2.0f).matrix == mat4.scaling(0.0f, 1.0f, 2.0f).matrix);
        }
        
        static if(isFloatingPoint!mt) {
            static private mt[6] cperspective(mt width, mt height, mt fov, mt near, mt far) {
                mt aspect = width/height;
                mt top = near * tan(fov*(PI/360.0));
                mt bottom = -top;
                mt right = top * aspect;
                mt left = -right;
                
                return [left, right, bottom, top, near, far];
            }
            
            /// Returns a perspective matrix (4x4 and floating-point matrices only).
            static Matrix perspective(mt width, mt height, mt fov = 60.0, mt near = 1.0, mt far = 100.0) {
                mt[6] cdata = cperspective(width, height, fov, near, far);
                return perspective(cdata[0], cdata[1], cdata[2], cdata[3], cdata[4], cdata[5]);
            }
            
            /// ditto
            static Matrix perspective(mt left, mt right, mt bottom, mt top, mt near, mt far) {
                Matrix ret;
                ret.clear(0);
                
                ret.matrix[0][0] = (2*near)/(right-left);
                ret.matrix[0][2] = (right+left)/(right-left);
                ret.matrix[1][1] = (2*near)/(top-bottom);
                ret.matrix[1][2] = (top+bottom)/(top-bottom);
                ret.matrix[2][2] = -(far+near)/(far-near);
                ret.matrix[2][3] = -(2*far*near)/(far-near);
                ret.matrix[3][2] = -1;
                
                return ret;
            }
            
            /// Returns an inverse perspective matrix (4x4 and floating-point matrices only).
            static Matrix perspective_inverse(mt width, mt height, mt fov = 60.0, mt near = 1.0, mt far = 100.0) {
                mt[6] cdata = cperspective(width, height, fov, near, far);
                return perspective_inverse(cdata[0], cdata[1], cdata[2], cdata[3], cdata[4], cdata[5]);
            }
            
            /// ditto
            static Matrix perspective_inverse(mt left, mt right, mt bottom, mt top, mt near, mt far) {
                Matrix ret;
                ret.clear(0);
                
                ret.matrix[0][0] = (right-left)/(2*near);
                ret.matrix[0][3] = (right+left)/(2*near);
                ret.matrix[1][1] = (top-bottom)/(2*near);
                ret.matrix[1][3] = (top+bottom)/(2*near);
                ret.matrix[2][3] = -1;
                ret.matrix[3][2] = -(far-near)/(2*far*near);
                ret.matrix[3][3] = (far+near)/(2*far*near);
                
                return ret;
            }
            
            // (2) and (3) say this one is correct
            /// Returns an orthographic matrix (4x4 and floating-point matrices only).
            static Matrix orthographic(mt left, mt right, mt bottom, mt top, mt near, mt far) {
                Matrix ret;
                ret.clear(0);
                
                ret.matrix[0][0] = 2/(right-left);
                ret.matrix[0][3] = -(right+left)/(right-left);
                ret.matrix[1][1] = 2/(top-bottom);
                ret.matrix[1][3] = -(top+bottom)/(top-bottom);
                ret.matrix[2][2] = -2/(far-near);
                ret.matrix[2][3] = -(far+near)/(far-near);
                ret.matrix[3][3] = 1;
                
                return ret;
            }
            
            // (1) and (2) say this one is correct 
            /// Returns an inverse ortographic matrix (4x4 and floating-point matrices only).
            static Matrix orthographic_inverse(mt left, mt right, mt bottom, mt top, mt near, mt far) {
                Matrix ret;
                ret.clear(0);
                
                ret.matrix[0][0] = (right-left)/2;
                ret.matrix[0][3] = (right+left)/2;
                ret.matrix[1][1] = (top-bottom)/2;
                ret.matrix[1][3] = (top+bottom)/2;
                ret.matrix[2][2] = (far-near)/-2;
                ret.matrix[2][3] = (far+near)/2;
                ret.matrix[3][3] = 1;
                
                return ret;
            }
            
            /// Returns a look at matrix (4x4 and floating-point matrices only).
            static Matrix look_at(Vector!(mt, 3) eye, Vector!(mt, 3) target, Vector!(mt, 3) up) {
                alias Vector!(mt, 3) vec3mt;
                vec3mt look_dir = (target - eye).normalized;
                vec3mt up_dir = up.normalized;
                
                vec3mt right_dir = cross(look_dir, up_dir).normalized;
                vec3mt perp_up_dir = cross(right_dir, look_dir);
                
                Matrix rot = Matrix.identity;
                rot.matrix[0][0..3] = right_dir.vector;
                rot.matrix[1][0..3] = perp_up_dir.vector;
                rot.matrix[2][0..3] = (-look_dir).vector;
                
                Matrix trans = Matrix.translation(-eye.x, -eye.y, -eye.z);
                
                return rot * trans;
            }
        
            unittest {               
                mt[6] cp = cperspective(600f, 900f, 60f, 1f, 100f);
                assert(cp[4] == 1.0f);
                assert(cp[5] == 100.0f);
                assert(cp[0] == -cp[1]);
                assert((cp[0] < -0.38489f) && (cp[0] > -0.38491f));
                assert(cp[2] == -cp[3]);
                assert((cp[2] < -0.577349f) && (cp[2] > -0.577351f));
                
                assert(mat4.perspective(600f, 900f) == mat4.perspective(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]));
                float[4][4] m4p = mat4.perspective(600f, 900f).matrix;
                assert((m4p[0][0] < 2.598077f) && (m4p[0][0] > 2.598075f));
                assert(m4p[0][2] == 0.0f);
                assert((m4p[1][1] < 1.732052) && (m4p[1][1] > 1.732050));
                assert(m4p[1][2] == 0.0f);
                assert((m4p[2][2] < -1.020201) && (m4p[2][2] > -1.020203));
                assert((m4p[2][3] < -2.020201) && (m4p[2][3] > -2.020203));
                assert((m4p[3][2] < -0.9f) && (m4p[3][2] > -1.1f));
                
                float[4][4] m4pi = mat4.perspective_inverse(600f, 900f).matrix;
                assert((m4pi[0][0] < 0.384901) && (m4pi[0][0] > 0.384899));
                assert(m4pi[0][3] == 0.0f);
                assert((m4pi[1][1] < 0.577351) && (m4pi[1][1] > 0.577349));
                assert(m4pi[1][3] == 0.0f);
                assert(m4pi[2][3] == -1.0f);
                assert((m4pi[3][2] < -0.494999) && (m4pi[3][2] > -0.495001));
                assert((m4pi[3][3] < 0.505001) && (m4pi[3][3] > 0.504999));

                // maybe the next tests should be improved
                float[4][4] m4o = mat4.orthographic(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f).matrix;
                assert(m4o == [[1.0f, 0.0f, 0.0f, 0.0f],
                               [0.0f, 1.0f, 0.0f, 0.0f],
                               [0.0f, 0.0f, -1.0f, 0.0f],
                               [0.0f, 0.0f, 0.0f, 1.0f]]);
               
                float[4][4] m4oi = mat4.orthographic_inverse(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f).matrix;
                assert(m4oi == [[1.0f, 0.0f, 0.0f, 0.0f],
                                [0.0f, 1.0f, 0.0f, 0.0f],
                                [0.0f, 0.0f, -1.0f, 0.0f],
                                [0.0f, 0.0f, 0.0f, 1.0f]]);
                                
                //TODO: look_at tests
            }
        
        }
        
    }

    static if((rows == cols) && (rows >= 3)) {
        /// Returns an identity matrix with an applied rotation around the x-axis (nxn matrices, n >= 3).
        static Matrix xrotation(real alpha) {
            Matrix mult = Matrix.identity;
            
            mt cosamt = to!mt(cos(alpha));
            mt sinamt = to!mt(sin(alpha));
            
            mult.matrix[1][1] = cosamt;
            mult.matrix[1][2] = -sinamt;
            mult.matrix[2][1] = sinamt;
            mult.matrix[2][2] = cosamt;
            
            return mult;
        }
        
        /// Returns an identity matrix with an applied rotation around the y-axis (nxn matrices, n >= 3).
        static Matrix yrotation(real alpha) {
            Matrix mult = Matrix.identity;
            
            mt cosamt = to!mt(cos(alpha));
            mt sinamt = to!mt(sin(alpha));
            
            mult.matrix[0][0] = cosamt;
            mult.matrix[0][2] = sinamt;
            mult.matrix[2][0] = -sinamt;
            mult.matrix[2][2] = cosamt;
            
            return mult;
        }
        
        /// Returns an identity matrix with an applied rotation around the z-axis (nxn matrices, n >= 3).
        static Matrix zrotation(real alpha) {
            Matrix mult = Matrix.identity;
            
            mt cosamt = to!mt(cos(alpha));
            mt sinamt = to!mt(sin(alpha));
            
            mult.matrix[0][0] = cosamt;
            mult.matrix[0][1] = -sinamt;
            mult.matrix[1][0] = sinamt;
            mult.matrix[1][1] = cosamt;
            
            return mult;
        }
        
        /// Rotates the current matrix around the x-axis and returns $(I this) (nxn matrices, n >= 3).
        Matrix rotatex(real alpha) {
            this = this * xrotation(alpha);
            return this;
        }
        
        /// Rotates the current matrix around the y-axis and returns $(I this) (nxn matrices, n >= 3).
        Matrix rotatey(real alpha) {
            this = this * yrotation(alpha);
            return this;
        }
        
        /// Rotates the current matrix around the z-axis and returns $(I this) (nxn matrices, n >= 3).
        Matrix rotatez(real alpha) {
            this = this * zrotation(alpha);
            return this;
        }
        
        unittest {
            assert(mat4.xrotation(0).matrix == [[1.0f, 0.0f, 0.0f, 0.0f],
                                                [0.0f, 1.0f, -0.0f, 0.0f],
                                                [0.0f, 0.0f, 1.0f, 0.0f],
                                                [0.0f, 0.0f, 0.0f, 1.0f]]);
            assert(mat4.yrotation(0).matrix == [[1.0f, 0.0f, 0.0f, 0.0f],
                                                [0.0f, 1.0f, 0.0f, 0.0f],
                                                [0.0f, 0.0f, 1.0f, 0.0f],
                                                [0.0f, 0.0f, 0.0f, 1.0f]]);
            assert(mat4.zrotation(0).matrix == [[1.0f, -0.0f, 0.0f, 0.0f],
                                                [0.0f, 1.0f, 0.0f, 0.0f],
                                                [0.0f, 0.0f, 1.0f, 0.0f],
                                                [0.0f, 0.0f, 0.0f, 1.0f]]);
            mat4 xro = mat4.identity;
            xro.rotatex(0);
            assert(mat4.xrotation(0).matrix == xro.matrix);
            assert(xro.matrix == mat4.identity.rotatex(0).matrix);
            mat4 yro = mat4.identity;
            yro.rotatey(0);
            assert(mat4.yrotation(0).matrix == yro.matrix);
            assert(yro.matrix == mat4.identity.rotatey(0).matrix);
            mat4 zro = mat4.identity;
            xro.rotatez(0);
            assert(mat4.zrotation(0).matrix == zro.matrix);
            assert(zro.matrix == mat4.identity.rotatez(0).matrix);
        }
        
        
        /// Sets the translation of the matrix (nxn matrices, n >= 3).
        void translation(mt[] values...) { // intended to be a property 
            assert(values.length >= (rows-1));
            
            for(int r = 0; r < (rows-1); r++) {
                matrix[r][rows-1] = values[r];
            }
        }
        
        /// Copyies the translation from mat to the current matrix (nxn matrices, n >= 3).
        void translation(Matrix mat) {
            for(int r = 0; r < (rows-1); r++) {
                matrix[r][rows-1] = mat.matrix[r][rows-1];
            }
        }
        
        /// Returns an identity matrix with the current translation applied (nxn matrices, n >= 3)..
        Matrix translation() {
            Matrix ret = Matrix.identity;
            
            for(int r = 0; r < (rows-1); r++) {
                ret.matrix[r][rows-1] = matrix[r][rows-1];
            }
            
            return ret;
        }
        
        unittest {
            mat3 m3 = mat3(0.0f, 1.0f, 2.0f,
                           3.0f, 4.0f, 5.0f,
                           6.0f, 7.0f, 1.0f);
            assert(m3.translation.matrix == [[1.0f, 0.0f, 2.0f], [0.0f, 1.0f, 5.0f], [0.0f, 0.0f, 1.0f]]);
            m3.translation = mat3.identity;
            assert(mat3.identity.matrix == m3.translation.matrix);
            m3.translation = [2.0f, 5.0f];
            assert(m3.translation.matrix == [[1.0f, 0.0f, 2.0f], [0.0f, 1.0f, 5.0f], [0.0f, 0.0f, 1.0f]]);
            assert(mat3.identity.matrix == mat3.identity.translation.matrix);

            mat4 m4 = mat4(0.0f, 1.0f, 2.0f, 3.0f,
                           4.0f, 5.0f, 6.0f, 7.0f,
                           8.0f, 9.0f, 10.0f, 11.0f,
                           12.0f, 13.0f, 14.0f, 1.0f);
            assert(m4.translation.matrix == [[1.0f, 0.0f, 0.0f, 3.0f],
                                       [0.0f, 1.0f, 0.0f, 7.0f],
                                       [0.0f, 0.0f, 1.0f, 11.0f],
                                       [0.0f, 0.0f, 0.0f, 1.0f]]);
            m4.translation = mat4.identity;
            assert(mat4.identity.matrix == m4.translation.matrix);
            m4.translation = [3.0f, 7.0f, 11.0f];
            assert(m4.translation.matrix == [[1.0f, 0.0f, 0.0f, 3.0f],
                                       [0.0f, 1.0f, 0.0f, 7.0f],
                                       [0.0f, 0.0f, 1.0f, 11.0f],
                                       [0.0f, 0.0f, 0.0f, 1.0f]]);
            assert(mat4.identity.matrix == mat4.identity.translation.matrix);
        }
        
        /// Sets the scale of the matrix (nxn matrices, n >= 3).
        void scale(mt[] values...) { // intended to be a property
            assert(values.length >= (rows-1));
            
            for(int r = 0; r < (rows-1); r++) {
                matrix[r][r] = values[r];
            }
        }
        
        /// Copyies the scale from mat to the current matrix (nxn matrices, n >= 3).
        void scale(Matrix mat) {
            for(int r = 0; r < (rows-1); r++) {
                matrix[r][r] = mat.matrix[r][r];
            }
        }
        
        /// Returns an identity matrix with the current scale applied (nxn matrices, n >= 3).
        Matrix scale() { 
            Matrix ret = Matrix.identity;
            
            for(int r = 0; r < (rows-1); r++) {
                ret.matrix[r][r] = matrix[r][r];
            }
            
            return ret;
        }
        
        unittest {
            mat3 m3 = mat3(0.0f, 1.0f, 2.0f,
                           3.0f, 4.0f, 5.0f,
                           6.0f, 7.0f, 1.0f);
            assert(m3.scale.matrix == [[0.0f, 0.0f, 0.0f], [0.0f, 4.0f, 0.0f], [0.0f, 0.0f, 1.0f]]);
            m3.scale = mat3.identity;
            assert(mat3.identity.matrix == m3.scale.matrix);
            m3.scale = [0.0f, 4.0f];
            assert(m3.scale.matrix == [[0.0f, 0.0f, 0.0f], [0.0f, 4.0f, 0.0f], [0.0f, 0.0f, 1.0f]]);
            assert(mat3.identity.matrix == mat3.identity.scale.matrix);

            mat4 m4 = mat4(0.0f, 1.0f, 2.0f, 3.0f,
                           4.0f, 5.0f, 6.0f, 7.0f,
                           8.0f, 9.0f, 10.0f, 11.0f,
                           12.0f, 13.0f, 14.0f, 1.0f);
            assert(m4.scale.matrix == [[0.0f, 0.0f, 0.0f, 0.0f],
                                       [0.0f, 5.0f, 0.0f, 0.0f],
                                       [0.0f, 0.0f, 10.0f, 0.0f],
                                       [0.0f, 0.0f, 0.0f, 1.0f]]);
            m4.scale = mat4.identity;
            assert(mat4.identity.matrix == m4.scale.matrix);
            m4.scale = [0.0f, 5.0f, 10.0f];
            assert(m4.scale.matrix == [[0.0f, 0.0f, 0.0f, 0.0f],
                                       [0.0f, 5.0f, 0.0f, 0.0f],
                                       [0.0f, 0.0f, 10.0f, 0.0f],
                                       [0.0f, 0.0f, 0.0f, 1.0f]]);
            assert(mat4.identity.matrix == mat4.identity.scale.matrix);
        }
        
        /// Copies rot into the upper left corner, the translation (nxn matrices, n >= 3).
        void rotation(Matrix!(mt, 3, 3) rot) { // intended to be a property
            for(int r = 0; r < 3; r++) {
                for(int c = 0; c < 3; c++) {
                    matrix[r][c] = rot[r][c];
                }
            }
        }
        
        /// Returns an identity matrix with the current rotation applied (nxn matrices, n >= 3).
        Matrix!(mt, 3, 3) rotation() {
            Matrix!(mt, 3, 3) ret = Matrix!(mt, 3, 3).identity;
            
            for(int r = 0; r < 3; r++) {
                for(int c = 0; c < 3; c++) {
                    ret.matrix[r][c] = matrix[r][c];
                }
            }
            
            return ret;
        }
        
        unittest {
            mat3 m3 = mat3(0.0f, 1.0f, 2.0f,
                           3.0f, 4.0f, 5.0f,
                           6.0f, 7.0f, 1.0f);
            assert(m3.rotation.matrix == [[0.0f, 1.0f, 2.0f], [3.0f, 4.0f, 5.0f], [6.0f, 7.0f, 1.0f]]);
            m3.rotation = mat3.identity;
            assert(mat3.identity.matrix == m3.rotation.matrix);
            m3.rotation = mat3(0.0f, 1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 1.0f);
            assert(m3.rotation.matrix == [[0.0f, 1.0f, 2.0f], [3.0f, 4.0f, 5.0f], [6.0f, 7.0f, 1.0f]]);
            assert(mat3.identity.matrix == mat3.identity.rotation.matrix);

            mat4 m4 = mat4(0.0f, 1.0f, 2.0f, 3.0f,
                           4.0f, 5.0f, 6.0f, 7.0f,
                           8.0f, 9.0f, 10.0f, 11.0f,
                           12.0f, 13.0f, 14.0f, 1.0f);
            assert(m4.rotation.matrix == [[0.0f, 1.0f, 2.0f], [4.0f, 5.0f, 6.0f], [8.0f, 9.0f, 10.0f]]);
            m4.rotation = mat3.identity;
            assert(mat3.identity.matrix == m4.rotation.matrix);
            m4.rotation = mat3(0.0f, 1.0f, 2.0f, 4.0f, 5.0f, 6.0f, 8.0f, 9.0f, 10.0f);
            assert(m4.rotation.matrix == [[0.0f, 1.0f, 2.0f], [4.0f, 5.0f, 6.0f], [8.0f, 9.0f, 10.0f]]);
            assert(mat3.identity.matrix == mat4.identity.rotation.matrix);
        }
        
    }
    
    static if((rows == cols) && (rows <= 4)) {
        /// Returns an inverted copy of the current matrix (nxn matrices, n <= 4).
        @property Matrix inverse() {
            Matrix mat;
            invert(mat);
            return mat;
        }
        
        /// Inverts the current matrix (nxn matrices, n <= 4).
        void invert() {
            invert(this);
        }
    }
    
    unittest {
        mat2 m2 = mat2(1.0f, 2.0f, vec2(3.0f, 4.0f));
        assert(m2.det == -2.0f);
        assert(m2.inverse.matrix == [[-2.0f, 1.0f], [1.5f, -0.5f]]);
        
        mat3 m3 = mat3(1.0f, -2.0f, 3.0f,
                       7.0f, -1.0f, 0.0f,
                       3.0f, 2.0f, -4.0f);
        assert(m3.det == -1.0f);
        assert(m3.inverse.matrix == [[-4.0f, 2.0f, -3.0f],
                                     [-28.0f, 13.0f, -21.0f],
                                     [-17.0f, 8.0f, -13.0f]]);

        mat4 m4 = mat4(1.0f, 2.0f, 3.0f, 4.0f,
                       -2.0f, 1.0f, 5.0f, -2.0f,
                       2.0f, -1.0f, 7.0f, 1.0f,
                       3.0f, -3.0f, 2.0f, 0.0f);
        assert(m4.det == -8.0f);
        assert(m4.inverse.matrix == [[6.875f, 7.875f, -11.75f, 11.125f],
                                     [6.625f, 7.625f, -11.25f, 10.375f],
                                     [-0.375f, -0.375f, 0.75f, -0.625f],
                                     [-4.5f, -5.5f, 8.0f, -7.5f]]);
    }

    private void mms(mt inp, ref Matrix mat) { // mat * scalar
        for(int r = 0; r < rows; r++) {
            for(int c = 0; c < cols; c++) {
                mat.matrix[r][c] = matrix[r][c] * inp;
            }
        }
    }

    private void masm(string op)(Matrix inp, ref Matrix mat) { // mat + or - mat
        for(int r = 0; r < rows; r++) {
            for(int c = 0; c < cols; c++) {
                mat.matrix[r][c] = mixin("inp.matrix[r][c]" ~ op ~ "matrix[r][c]");
            }
        }
    }
    
    Matrix!(mt, rows, T.cols) opBinary(string op : "*", T)(T inp) if(isCompatibleMatrix!T && (T.rows == cols)) {
        Matrix!(mt, rows, T.cols) ret;
        
        for(int r = 0; r < rows; r++) { 
            for(int c = 0; c < T.cols; c++) {
                ret.matrix[r][c] = 0;
                for(int c2 = 0; c2 < cols; c2++) {
                    ret.matrix[r][c] += matrix[r][c2] * inp.matrix[c2][c];
                }
            }
        }
        
        return ret;
    }
    
    Vector!(mt, rows) opBinary(string op : "*", T : Vector!(mt, cols))(T inp) {
        Vector!(mt, rows) ret;
        ret.clear(0);
        
        for(int r = 0; r < rows; r++) {
            for(int c = 0; c < cols; c++) {
                ret.vector[r] += matrix[r][c] * inp.vector[c];
            }
        }
        
        return ret;
    }
    
    Matrix opBinary(string op : "*")(mt inp) {
        Matrix ret;
        mms(inp, ret);
        return ret;       
    }
    
    Matrix opBinaryRight(string op : "*")(mt inp) {
        return this.opBinary!(op)(inp);
    }
    
    Matrix opBinary(string op)(Matrix inp) if((op == "+") || (op == "-")) {
        Matrix ret;
        masm!(op)(inp, ret);
        return ret;
    }
    
    void opOpAssign(string op : "*")(mt inp) {
        mms(inp, this);
    }

    void opOpAssign(string op)(Matrix inp) if((op == "+") || (op == "-")) {
        masm!(op)(inp, this);
    }
    
    unittest {
        mat2 m2 = mat2(1.0f, 2.0f, 3.0f, 4.0f);
        vec2 v2 = vec2(2.0f, 2.0f);
        assert((m2*2).matrix == [[2.0f, 4.0f], [6.0f, 8.0f]]);
        assert((2*m2).matrix == (m2*2).matrix);
        m2 *= 2;
        assert(m2.matrix == [[2.0f, 4.0f], [6.0f, 8.0f]]);
        assert((m2*v2).vector == [12.0f, 28.0f]);
        assert((v2*m2).vector == (m2*v2).vector);
        assert((m2*m2).matrix == [[28.0f, 40.0f], [60.0f, 88.0f]]);
        assert((m2-m2).matrix == [[0.0f, 0.0f], [0.0f, 0.0f]]);
        assert((m2+m2).matrix == [[4.0f, 8.0f], [12.0f, 16.0f]]);
        m2 += m2;
        assert(m2.matrix == [[4.0f, 8.0f], [12.0f, 16.0f]]);
        m2 -= m2;
        assert(m2.matrix == [[0.0f, 0.0f], [0.0f, 0.0f]]);

        mat3 m3 = mat3(1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f);
        vec3 v3 = vec3(2.0f, 2.0f, 2.0f);
        assert((m3*2).matrix == [[2.0f, 4.0f, 6.0f], [8.0f, 10.0f, 12.0f], [14.0f, 16.0f, 18.0f]]);
        assert((2*m3).matrix == (m3*2).matrix);
        m3 *= 2;
        assert(m3.matrix == [[2.0f, 4.0f, 6.0f], [8.0f, 10.0f, 12.0f], [14.0f, 16.0f, 18.0f]]);
        assert((m3*v3).vector == [24.0f, 60.0f, 96.0f]);
        assert((v3*m3).vector == (m3*v3).vector);
        assert((m3*m3).matrix == [[120.0f, 144.0f, 168.0f], [264.0f, 324.0f, 384.0f], [408.0f, 504.0f, 600.0f]]);
        assert((m3-m3).matrix == [[0.0f, 0.0f, 0.0f], [0.0f, 0.0f, 0.0f], [0.0f, 0.0f, 0.0f]]);
        assert((m3+m3).matrix == [[4.0f, 8.0f, 12.0f], [16.0f, 20.0f, 24.0f], [28.0f, 32.0f, 36.0f]]);
        m3 += m3;
        assert(m3.matrix == [[4.0f, 8.0f, 12.0f], [16.0f, 20.0f, 24.0f], [28.0f, 32.0f, 36.0f]]);
        m3 -= m3;
        assert(m3.matrix == [[0.0f, 0.0f, 0.0f], [0.0f, 0.0f, 0.0f], [0.0f, 0.0f, 0.0f]]);
        
        //TODO: tests for mat4, mat34
    }

    // opEqual => "alias matrix this;"
    
    bool opCast(T : bool)() {
        return ok;
    }
    
    unittest {
        assert(mat2(1.0f, 2.0f, 1.0f, 1.0f) == mat2(1.0f, 2.0f, 1.0f, 1.0f));
        assert(mat2(1.0f, 2.0f, 1.0f, 1.0f) != mat2(1.0f, 1.0f, 1.0f, 1.0f));
                
        assert(mat3(1.0f) == mat3(1.0f));
        assert(mat3(1.0f) != mat3(2.0f));
                
        assert(mat4(1.0f) == mat4(1.0f));
        assert(mat4(1.0f) != mat4(2.0f));
    
        assert(!(mat4(float.nan)));
        if(mat4(1.0f)) { }
        else { assert(false); }
    }
    
}

/// Pre-defined matrix types, the first number represents the number of rows 
/// and the second the number of columns, if there's just one it's a nxn matrix.
/// All of these matrices are floating-point matrices.
alias Matrix!(float, 2, 2) mat2;
alias Matrix!(float, 3, 3) mat3;
alias Matrix!(float, 3, 4) mat34;
alias Matrix!(float, 4, 4) mat4;

/// Base template for all quaternion-types.
/// Params:
///  type = all values get stored as this type
struct Quaternion(type) {
    alias type qt; /// Holds the internal type of the quaternion.
    
    qt[4] quaternion; /// Holds the w, x, y and z coordinates.
    
    /// Returns a pointer to the quaternion in memory, it starts with the w coordinate.
    @property auto value_ptr() { return quaternion.ptr; }
    
    private @property qt get_(char coord)() {
        return quaternion[coord_to_index!coord];
    }
    private @property void set_(char coord)(qt value) {
        quaternion[coord_to_index!coord] = value;
    }
    
    alias get_!'w' w; /// static properties to access the values.
    alias set_!'w' w;
    alias get_!'x' x; /// ditto
    alias set_!'x' x;
    alias get_!'y' y; /// ditto
    alias set_!'y' y;
    alias get_!'z' z; /// ditto
    alias set_!'z' z;

    /// Constructs the quaternion.
    /// Takes a 4-dimensional vector, where vector.x = the quaternions w coordinate,
    /// or a w coordinate of type $(I qt) and a 3-dimensional vector representing the imaginary part,
    /// or 4 values of type $(I qt).
    this(qt w_, qt x_, qt y_, qt z_) {
        w = w_;
        x = x_;
        y = y_;
        z = z_;
    }
    
    /// ditto
    this(qt w_, Vector!(qt, 3) vec) {
        w = w_;
        quaternion[1..4] = vec.vector;
    }
    
    /// ditto
    this(Vector!(qt, 4) vec) {
        quaternion = vec.vector;
    }
    
    /// Returns true if all values are not nan and finite, otherwise false.
    @property bool ok() {
        foreach(q; quaternion) {
            if(isNaN(q) || isInfinity(q)) {
                return false;
            }
        }
        return true;
    }
       
    unittest {
        quat q1 = quat(0.0f, 0.0f, 0.0f, 1.0f);
        assert(q1.quaternion == [0.0f, 0.0f, 0.0f, 1.0f]);
        assert(q1.quaternion == quat(0.0f, 0.0f, 0.0f, 1.0f).quaternion);
        assert(q1.quaternion == quat(0.0f, vec3(0.0f, 0.0f, 1.0f)).quaternion);
        assert(q1.quaternion == quat(vec4(0.0f, 0.0f, 0.0f, 1.0f)).quaternion);
        
        assert(q1.ok);
        q1.x = float.infinity;
        assert(!q1.ok);
        q1.x = float.nan;
        assert(!q1.ok);
        q1.x = 0.0f;
        assert(q1.ok);
    }
    
    template coord_to_index(char c) {
        static if(c == 'w') {
            enum coord_to_index = 0;
        } else static if(c == 'x') {
            enum coord_to_index = 1;
        } else static if(c == 'y') {
            enum coord_to_index = 2;
        } else static if(c == 'z') {
            enum coord_to_index = 3;
        } else {
            static assert(false, "accepted coordinates are x, y, z and w not " ~ c ~ ".");
        }
    }
    
    /// Returns the squared magnitude of the quaternion.
    @property real magnitude_squared() {
        return to!real(w^^2 + x^^2 + y^^2 + z^^2);
    }
    
    /// Returns the magnitude of the quaternion.
    @property real magnitude() {
        return sqrt(magnitude_squared);
    }
    
    /// Returns an identity quaternion (w=1, x=0, y=0, z=0).
    static @property Quaternion identity() {
        return Quaternion(1, 0, 0, 0);
    }
    
    /// Makes the current quaternion an identity quaternion.
    void make_identity() {
        w = 1;
        x = 0;
        y = 0;
        z = 0;
    }
    
    /// Inverts the quaternion.
    void invert() {
        x = -x;
        y = -y;
        z = -z;
    }
    alias invert conjugate; /// ditto
    
    /// Returns an inverted copy of the current quaternion.
    @property Quaternion inverse() {
        return Quaternion(w, -x, -y, -z);
    }
    alias inverse conjugated; /// ditto
    
    unittest {
        quat q1 = quat(1.0f, 1.0f, 1.0f, 1.0f);
        
        assert(q1.magnitude == 2.0f);
        assert(q1.magnitude_squared == 4.0f);
        assert(q1.magnitude == quat(0.0f, 0.0f, 2.0f, 0.0f).magnitude);
        
        quat q2 = quat.identity;
        assert(q2.quaternion == [1.0f, 0.0f, 0.0f, 0.0f]);
        assert(q2.x == 0.0f);
        assert(q2.y == 0.0f);
        assert(q2.z == 0.0f);
        assert(q2.w == 1.0f);
        
        assert(q1.inverse.quaternion == [1.0f, -1.0f, -1.0f, -1.0f]);
        q1.invert();
        assert(q1.quaternion == [1.0f, -1.0f, -1.0f, -1.0f]);
        
        q1.make_identity();
        assert(q1.quaternion == q2.quaternion);
        
    }
    
    /// Returns the current vector formatted as string, useful for printing the quaternion.
    @property string as_string() {
        return format(isFloatingPoint!(qt) ? "%f":"%s", quaternion);
    }
    alias as_string toString;

    /// Creates a quaternion from a 3x3 matrix.
    /// Params:
    ///  matrix = 3x3 matrix (rotation)
    /// Returns: A quaternion representing the rotation (3x3 matrix)
    static Quaternion from_matrix(Matrix!(qt, 3, 3) matrix) {
        Quaternion ret;
        
        auto mat = matrix.matrix;
        qt trace = mat[0][0] + mat[1][1] + mat[2][2];
        
        if(trace > 0) {
            real s = 0.5 / sqrt(trace + 1.0);
            
            ret.w = to!qt(0.25 / s);
            ret.x = to!qt((mat[2][1] - mat[1][2]) * s);
            ret.y = to!qt((mat[0][2] - mat[2][0]) * s);
            ret.z = to!qt((mat[1][0] - mat[0][1]) * s);
        } else if((mat[0][0] > mat[1][2]) && (mat[0][0] > mat[2][2])) {
            real s = 2.0 * sqrt(1 + mat[0][0] - mat[1][1] - mat[2][2]);
            
            ret.w = to!qt((mat[2][1] - mat[1][2]) / s);
            ret.x = to!qt(0.25 * s);
            ret.y = to!qt((mat[0][1] - mat[1][0]) / s);
            ret.z = to!qt((mat[0][2] - mat[2][0]) / s);
        } else if(mat[1][1] > mat[2][2]) {
            real s = 2.0 * sqrt(1 + mat[1][1] - mat[0][0] - mat[2][2]);
            
            ret.w = to!qt((mat[0][2] - mat[2][0]) / s);
            ret.x = to!qt((mat[0][1] + mat[1][0]) / s);
            ret.y = to!qt(0.25f * s);
            ret.z = to!qt((mat[1][2] + mat[2][1]) / s);
        } else {
            real s = 2.0 * sqrt(1 + mat[2][2] - mat[0][0] - mat[1][1]);

            ret.w = to!qt((mat[1][0] - mat[0][1]) / s);
            ret.x = to!qt((mat[0][2] + mat[2][0]) / s);
            ret.y = to!qt((mat[1][2] + mat[2][1]) / s);
            ret.z = to!qt(0.25f * s);
        }
        
        return ret;
    }
    
    /// Returns the quaternion as matrix.
    /// Params:
    ///  rows = number of rows of the resulting matrix (min 3)
    ///  cols = number of columns of the resulting matrix (min 3)
    Matrix!(qt, rows, cols) to_matrix(int rows, int cols)() if((rows >= 3) && (cols >= 3)) {
        static if((rows == 3) && (cols == 3)) {
            Matrix!(qt, rows, cols) ret;
        } else {
            Matrix!(qt, rows, cols) ret = Matrix!(qt, rows, cols).identity;
        }
                
        qt xx = x^^2;
        qt xy = x * y;
        qt xz = x * z;
        qt xw = x * w;
        qt yy = y^^2;
        qt yz = y * z;
        qt yw = y * w;
        qt zz = z^^2;
        qt zw = z * w;
        
        ret.matrix[0][0..3] = [1 - 2 * (yy + zz), 2 * (xy - zw), 2 * (xz + yw)];
        ret.matrix[1][0..3] = [2 * (xy + zw), 1 - 2 * (xx + zz), 2 * (yz - xw)];
        ret.matrix[2][0..3] = [2 * (xz - yw), 2 * (yz + xw), 1 - 2 * (xx + yy)];
        
        return ret;
    }
    
    unittest {
        quat q1 = quat(4.0f, 1.0f, 2.0f, 3.0f);
        
        assert(q1.to_matrix!(3, 3).matrix == [[-25.0f, -20.0f, 22.0f], [28.0f, -19.0f, 4.0f], [-10.0f, 20.0f, -9.0f]]);
        assert(q1.to_matrix!(4, 4).matrix == [[-25.0f, -20.0f, 22.0f, 0.0f],
                                              [28.0f, -19.0f, 4.0f, 0.0f],
                                              [-10.0f, 20.0f, -9.0f, 0.0f],
                                              [0.0f, 0.0f, 0.0f, 1.0f]]);
        assert(quat.identity.to_matrix!(3, 3).matrix == Matrix!(qt, 3, 3).identity.matrix);
        assert(q1.quaternion == quat.from_matrix(q1.to_matrix!(3, 3)).quaternion);

        assert(quat(1.0f, 0.0f, 0.0f, 0.0f).quaternion == quat.from_matrix(mat3.identity).quaternion);
        
        quat q2 = quat.from_matrix(mat3(1.0f, 3.0f, 2.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f));
        assert(q2.x == 0.0f);
        assert((q2.y > 0.7071066f) && (q2.y < 7071068f));
        assert((q2.z > -1.060661f) && (q2.z < -1.060659));
        assert((q2.w > 0.7071066f) && (q2.w < 7071068f));
    }
    
    /// Normalizes the current quaternion.
    void normalize() {
        qt m = to!qt(magnitude);
        
        if(m != 0) {
            w = w / m;
            x = x / m;
            y = y / m;
            z = z / m;
        }
    }
    
    /// Returns a normalized copy of the current quaternion.
    Quaternion normalized() {
        Quaternion ret;
        qt m = to!qt(magnitude);
        
        if(m != 0) {
            ret.w = w / m;
            ret.x = x / m;
            ret.y = y / m;
            ret.z = z / m;
        } else {
            ret = Quaternion(w, x, y, z);
        }
        
        return ret;
    }
    
    unittest {
        quat q1 = quat(1.0f, 2.0f, 3.0f, 4.0f);
        quat q2 = quat(1.0f, 2.0f, 3.0f, 4.0f);
        
        q1.normalize();
        assert(q1.quaternion == q2.normalized.quaternion);
        //assert(q1.quaternion == q1.normalized.quaternion);
        assert(q1.magnitude > 0.9999999);
        assert(q1.magnitude < 1.0000001);    
    }
    
    /// Returns the yaw.
    @property real yaw() {
        return atan2(to!real(2 * (w*y + x*z)), to!real(w^^2 - x^^2 - y^^2 + z^^2));
    }
    
    /// Returns the pitch.
    @property real pitch() {
        return asin(to!real(2 * (w*x - y*z)));
    }
    
    /// Returns the roll.
    @property real roll() {
        return atan2(to!real(2 * (w*z + x*y)), to!real(w^^2 - x^^2 + y^^2 - z^^2));
    }
    
    unittest {
        quat q1 = quat.identity;
        assert(q1.pitch == 0.0f);
        assert(q1.yaw == 0.0f);
        assert(q1.roll == 0.0f);
        
        quat q2 = quat(1.0f, 1.0f, 1.0f, 1.0f);
        assert(q2.yaw == q2.roll);
        assert((q2.yaw > 1.5707f) && (q2.yaw < 1.5709f));
        assert(q2.pitch == 0.0f);
        
        quat q3 = quat(0.1f, 1.9f, 2.1f, 1.3f);
        assert((q3.yaw > 2.4381f) && (q3.yaw < 2.4383f));
        assert(isNaN(q3.pitch));
        assert((q3.roll > 1.67718f) && (q3.roll < 1.6772f));
    }
    
    /// Returns a quaternion with applied rotation around the x-axis.
    static Quaternion xrotation(real alpha) {
        Quaternion ret;
        
        alpha /= 2;
        ret.w = to!qt(cos(alpha));
        ret.x = to!qt(sin(alpha));
        ret.y = 0;
        ret.z = 0;
        
        return ret;
    }
    
    /// Returns a quaternion with applied rotation around the y-axis.
    static Quaternion yrotation(real alpha) {
        Quaternion ret;
        
        alpha /= 2;
        ret.w = to!qt(cos(alpha));
        ret.x = 0;
        ret.y = to!qt(sin(alpha));
        ret.z = 0;
        
        return ret;
    }
    
    /// Returns a quaternion with applied rotation around the z-axis.
    static Quaternion zrotation(real alpha) {
        Quaternion ret;
        
        alpha /= 2;
        ret.w = to!qt(cos(alpha));
        ret.x = 0;
        ret.y = 0;
        ret.z = to!qt(sin(alpha));
        
        return ret;
    }
    
    /// Returns a quaternion with applied rotation around an axis.
    static Quaternion axis_rotation(Vector!(qt, 3) axis, real alpha) {
        if(alpha == 0) {
            return Quaternion.identity;
        }
        Quaternion ret;
        
        alpha /= 2;
        qt sinaqt = to!qt(sin(alpha));
        
        ret.w = to!qt(cos(alpha));
        ret.x = axis.x * sinaqt;
        ret.y = axis.y * sinaqt;
        ret.z = axis.z * sinaqt;
        
        return ret;
    }
    
    /// Creates a quaternion from an euler rotation.
    static Quaternion euler_rotation(real heading, real attitude, real bank) {
        Quaternion ret;
        
        real c1 = cos(heading / 2);
        real s1 = sin(heading / 2);
        real c2 = cos(attitude / 2);
        real s2 = sin(attitude / 2);
        real c3 = cos(bank / 2);
        real s3 = sin(bank / 2);
        
        ret.w = to!qt(c1 * c2 * c3 - s1 * s2 * s3);
        ret.x = to!qt(s1 * s2 * c3 + c1 * c2 * s3);
        ret.y = to!qt(s1 * c2 * c3 + c1 * s2 * s3);
        ret.z = to!qt(c1 * s2 * c3 - s1 * c2 * s3);
        
        return ret;
    }
    
    /// Rotates the current quaternion around the x-axis and returns $(I this).
    Quaternion rotatex(real alpha) {
        this *= xrotation(alpha);
        return this;
    }
    
    /// Rotates the current quaternion around the y-axis and returns $(I this).
    Quaternion rotatey(real alpha) {
        this *= yrotation(alpha);
        return this;
    }
    
    /// Rotates the current quaternion around the z-axis and returns $(I this).
    Quaternion rotatez(real alpha) {
        this *= zrotation(alpha);
        return this;
    }
    
    /// Rotates the current quaternion around an axis and returns $(I this).
    Quaternion rotate_axis(Vector!(qt, 3) axis, real alpha) {
        this *= axis_rotation(axis, alpha);
        return this;
    }
    
    /// Applies an euler rotation to the current quaternion and returns $(I this).
    Quaternion rotate_euler(real heading, real attitude, real bank) {
        this *= euler_rotation(heading, attitude, bank);
        return this;
    }
    
    unittest {
        assert(quat.xrotation(PI).quaternion[1..4] == [1.0f, 0.0f, 0.0f]);
        assert(quat.yrotation(PI).quaternion[1..4] == [0.0f, 1.0f, 0.0f]);
        assert(quat.zrotation(PI).quaternion[1..4] == [0.0f, 0.0f, 1.0f]);
        assert((quat.xrotation(PI).w == quat.yrotation(PI).w) && (quat.yrotation(PI).w == quat.zrotation(PI).w));
        //assert(quat.rotatex(PI).w == to!(quat.qt)(cos(PI)));
        assert(quat.xrotation(PI).quaternion == quat.identity.rotatex(PI).quaternion);
        assert(quat.yrotation(PI).quaternion == quat.identity.rotatey(PI).quaternion);
        assert(quat.zrotation(PI).quaternion == quat.identity.rotatez(PI).quaternion);
        
        assert(quat.axis_rotation(vec3(1.0f, 1.0f, 1.0f), PI).quaternion[1..4] == [1.0f, 1.0f, 1.0f]);
        assert(quat.axis_rotation(vec3(1.0f, 1.0f, 1.0f), PI).w == quat.xrotation(PI).w);
        assert(quat.axis_rotation(vec3(1.0f, 1.0f, 1.0f), PI).quaternion ==
               quat.identity.rotate_axis(vec3(1.0f, 1.0f, 1.0f), PI).quaternion);
        
        quat q1 = quat.euler_rotation(PI, PI, PI);
        assert((q1.x > -2.71052e-20) && (q1.x < -2.71050e-20));
        assert((q1.y > -2.71052e-20) && (q1.y < -2.71050e-20));
        assert((q1.z > 2.71050e-20) && (q1.z < 2.71052e-20));
        assert(q1.w == -1.0f);
        assert(quat.euler_rotation(PI, PI, PI).quaternion == quat.identity.rotate_euler(PI, PI, PI).quaternion);
    }
   
    Quaternion opBinary(string op : "*")(Quaternion inp) {
        Quaternion ret;
        
        ret.w = -x * inp.x - y * inp.y - z * inp.z + w * inp.w;
        ret.x = x * inp.w + y * inp.z - z * inp.y + w * inp.x;
        ret.y = -x * inp.z + y * inp.w + z * inp.x + w * inp.y;
        ret.z = x * inp.y - y * inp.x + z * inp.w + w * inp.z;
        
        return ret;
    }
    
    auto opBinaryRight(string op, T)(T inp) if(!is_quaternion!T) {
        return this.opBinary!(op)(inp);
    }
       
    Quaternion opBinary(string op)(Quaternion inp) if((op == "+") || (op == "-")) {
        Quaternion ret;
        
        mixin("ret.w = w" ~ op ~ "inp.w;");
        mixin("ret.x = x" ~ op ~ "inp.x;");
        mixin("ret.y = y" ~ op ~ "inp.y;");
        mixin("ret.z = z" ~ op ~ "inp.z;");
        
        return ret;
    }
    
    Vector!(qt, 3) opBinary(string op : "*")(Vector!(qt, 3) inp) {
        Vector!(qt, 3) ret;
        
        qt ww = w^^2;
        qt w2 = w * 2;
        qt wx2 = w2 * x;
        qt wy2 = w2 * y;
        qt wz2 = w2 * z;
        qt xx = x^^2;
        qt x2 = x * 2;
        qt xy2 = x2 * y;
        qt xz2 = x2 * z;
        qt yy = y^^2;
        qt yz2 = 2 * y * z;
        qt zz = z * z;
        
        ret.vector =  [ww * inp.x + wy2 * inp.z - wz2 * inp.y + xx * inp.x +
                       xy2 * inp.y + xz2 * inp.z - zz * inp.x - yy * inp.x,
                       xy2 * inp.x + yy * inp.y + yz2 * inp.z + wz2 * inp.x -
                       zz * inp.y + ww * inp.y - wx2 * inp.z - xx * inp.y,
                       xz2 * inp.x + yz2 * inp.y + zz * inp.z - wy2 * inp.x -
                       yy * inp.z + wx2 * inp.y - xx * inp.z + ww * inp.z];
       
       return ret;        
    }
    
    Quaternion opBinary(string op : "*")(qt inp) {
        return Quaternion(w*inp, x*inp, y*inp, z*inp);
    }
    
    void opOpAssign(string op : "*")(Quaternion inp) {
        qt w2 = -x * inp.x - y * inp.y - z * inp.z + w * inp.w;
        qt x2 = x * inp.w + y * inp.z - z * inp.y + w * inp.x;
        qt y2 = -x * inp.z + y * inp.w + z * inp.x + w * inp.y;
        qt z2 = x * inp.y - y * inp.x + z * inp.w + w * inp.z;
        w = w2; x = x2; y = y2; z = z2;
    }

    void opOpAssign(string op)(Quaternion inp) if((op == "+") || (op == "-")) {
        mixin("w = w" ~ op ~ "inp.w;");
        mixin("x = x" ~ op ~ "inp.x;");
        mixin("y = y" ~ op ~ "inp.y;");
        mixin("z = z" ~ op ~ "inp.z;");
    }
    
    void opOpAssign(string op : "*")(qt inp) {
        quaternion[0] *= inp;
        quaternion[1] *= inp;
        quaternion[2] *= inp;
        quaternion[3] *= inp;
    }
    
    unittest {
        quat q1 = quat.identity;
        quat q2 = quat(3.0f, 0.0f, 1.0f, 2.0f);
        quat q3 = quat(3.4f, 0.1f, 1.2f, 2.3f);
        
        assert((q1 * q1).quaternion == q1.quaternion);
        assert((q1 * q2).quaternion == q2.quaternion);
        assert((q2 * q1).quaternion == q2.quaternion);
        quat q4 = q3 * q2;
        assert((q2 * q3).quaternion != q4.quaternion);
        q3 *= q2;
        assert(q4.quaternion == q3.quaternion);
        assert((q4.x > 0.399999f) && (q4.x < 0.400001f));
        assert((q4.y > 6.799999f) && (q4.y < 6.800001f));
        assert((q4.z > 13.799999f) && (q4.z < 13.800001f));
        assert((q4.w > 4.399999f) && (q4.w < 4.400001f));

        quat q5 = quat(1.0f, 2.0f, 3.0f, 4.0f);
        quat q6 = quat(3.0f, 1.0f, 6.0f, 2.0f);
        
        assert((q5 - q6).quaternion == [-2.0f, 1.0f, -3.0f, 2.0f]);
        assert((q5 + q6).quaternion == [4.0f, 3.0f, 9.0f, 6.0f]);        
        assert((q6 - q5).quaternion == [2.0f, -1.0f, 3.0f, -2.0f]);
        assert((q6 + q5).quaternion == [4.0f, 3.0f, 9.0f, 6.0f]);
        q5 += q6;
        assert(q5.quaternion == [4.0f, 3.0f, 9.0f, 6.0f]);
        q6 -= q6;
        assert(q6.quaternion == [0.0f, 0.0f, 0.0f, 0.0f]);
        
        quat q7 = quat(2.0f, 2.0f, 2.0f, 2.0f);
        assert((q7 * 2).quaternion == [4.0f, 4.0f, 4.0f, 4.0f]);
        assert((2 * q7).quaternion == (q7 * 2).quaternion);
        q7 *= 2;
        assert(q7.quaternion == [4.0f, 4.0f, 4.0f, 4.0f]);
        
        vec3 v1 = vec3(1.0f, 2.0f, 3.0f);
        assert((q1 * v1).vector == v1.vector);
        assert((v1 * q1).vector == (q1 * v1).vector);
        assert((q2 * v1).vector == [-2.0f, 36.0f, 38.0f]);
    }

    const bool opEquals(ref const Quaternion qu) {
        return quaternion == qu.quaternion;
    }
    
    bool opCast(T : bool)() {
        return ok;
    }
    
    unittest {
        assert(quat(1.0f, 2.0f, 3.0f, 4.0f) == quat(1.0f, 2.0f, 3.0f, 4.0f));
        assert(quat(1.0f, 2.0f, 3.0f, 4.0f) != quat(1.0f, 2.0f, 3.0f, 3.0f));
    
        assert(!(quat(float.nan, float.nan, float.nan, float.nan)));
        if(quat(1.0f, 1.0f, 1.0f, 1.0f)) { }
        else { assert(false); }
    }
    
}

/// Pre-defined quaternion of type float.
alias Quaternion!(float) quat;