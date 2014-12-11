require 'securerandom'
require 'erb'
require 'ode'
require 'matrix'

class Simulator

  def initialize(q0, dt=0.003)
    @t = 0
    @q = q0
    @dt = dt
    @uuid = SecureRandom.uuid.to_s

    a_m = Matrix[
                   [0.10040000,    0.3369100000,   -0.009839500,   -0.10040000,   -0.3369100000,    0.009839600],
                   [0.02660000,    0.2744800000,   -0.040385000,    0.02660100,    0.2744800000,   -0.040385000],
                   [0.01359800,    0.0896640000,   -0.030640000,   -0.01359800,   -0.0896640000,    0.030641000],
                   [-0.00587510,   -0.0218080000,    0.000257370,   -0.00587420,   -0.0218080000,    0.000257350],
                   [-0.00603440,   -0.0201280000,    0.007621000,    0.00603430,    0.0201280000,   -0.007620800],
                   [0.00107040,    0.0007032000,    0.000894000,    0.00106990,    0.0007031400,    0.000893990],
                   [-0.00108030,    0.0009164100,    0.000200350,    0.00108030,   -0.0009162300,   -0.000199950],
                   [-0.00058078,    0.0015962000,   -0.000990470,   -0.00058046,    0.0015963000,   -0.000990450]
                 ];

    b_m = Matrix[
                   [0.07008300,    0.0705060000,   -0.365110000,   -0.07008300,   -0.0705060000,   0.365110000],
                   [-0.04120800,   -0.0876710000,   -0.040326000,   -0.04120800,   -0.0876710000,   -0.040325000],
                   [-0.06295500,    0.0496820000,   -0.015434000,    0.06295500,   -0.0496810000,    0.015433000],
                   [-0.00579400,    0.0145130000,   -0.001571600,   -0.00579390,    0.0145130000,   -0.001571500],
                   [0.00502140,   -0.0167810000,    0.006035400,   -0.00502200,    0.0167810000,   -0.006036200],
                   [0.00487940,   -0.0036696000,    0.000042587,    0.00487990,   -0.0036695000,    0.000042384],
                   [0.00270260,    0.0020633000,   -0.001726300,   -0.00270320,   -0.0020634000,    0.001726600],
                   [-0.00065561,   -0.0000048074,   -0.000240660,   -0.00065558,   -0.0000049165,   -0.000240570]
                 ];

    t_l = 1.135

    @proc = Proc.new {|t, q, f_args|
      coff = (2*Math::PI)/t_l
      cos_vec = []; sin_vec = []
      (1..8).each do |i|
        cos_vec.push(-((i*coff)**2)*Math.cos(i*coff*t))
        sin_vec.push(-((i*coff)**2)*Math.sin(i*coff*t))
      end
      q[9..17] + [0.0, 0.0, 0.0] + ((a_m.transpose * Vector[*cos_vec]) + (b_m.transpose * Vector[*sin_vec])).to_a
    }
    @n_buffer = 150
  end

  def run_n(n)
    @r ||= Ode::Solver.new(@proc).init(@t, @q)
    ret = []
    n.times do |i|
      @t += @dt
      @r.integrate(@t)
      ret.push([3*Math::PI/2,0.0,1.05] + @r.y[3..8].clone)
    end
    ret
  end

  def get_msg(msg)
    STDERR.puts("called!!")
    n = msg["num"]
    arr = self.run_n(n)
    @wid.send({new_arr: arr})
  end

  def run
    path = File.expand_path("../templates/widget.erb", __FILE__)

    uuid = '"' + @uuid + '"'
    initial_arr = self.run_n(@n_buffer)
    buffer_size = @n_buffer

    template = File.read(path)
    content = ERB.new(template).result(binding)

    IRuby.display '<div><svg></svg></div><script>' + content + '</script>', mime: 'text/html'
    @wid = SimWidget.new
    @wid.on_msg(self.method(:get_msg))
    wid.to_iruby
  end

  attr_reader :wid
end

class SimWidget < IRuby::Widget
  @@view_name = "SimView"
end

path = File.expand_path("../templates/init.js", __FILE__)
IRuby.display '<script>' + File.read(path) + '</script>', mime: 'text/html'
