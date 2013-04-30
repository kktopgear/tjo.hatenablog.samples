function [yvec,wvec,bias]=tjo_perceptron_3d_main_procedure(xvec)
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3次元単純パーセプトロン by Takashi J. OZAKI %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 非常に単純なパーセプトロンの実装です。
% 3次元と明記してありますが、汎用性のあるコードにしてありますので
% 基本的には何次元のデータに対しても正しく動きます。
% 例えば、[yvec,wvec]=tjo_perceptron_3d_main_procedure([1;2;3])
% とコマンドラインで入力してみて下さい。

% 基本的な原理については『サポートベクターマシン入門』（通称「赤本」）の
% 2章を読めば大体ご理解頂けるかと思います。本書を借りたい方は尾崎まで
% ご一報下さい。

% 今回は最も単純な主形式表現に基づいてコードを書いています。
% サポートベクターマシンへの発展で不可欠な双対表現は今回は省略しました。
% また、マージン処理も今回は省いてあります（マージンをいじった方が分離
% パフォーマンスは向上します…が、それならSVMを作った方が良いです）。

% 端的に言えば、単純パーセプトロンは以下のアルゴリズムで動きます。
% 以下の線型識別関数
% 
% y = w'x + b　（w:重みベクトル、x:入力ベクトル、b:バイアス）
% 
% 即ち重みベクトルと入力ベクトルの内積とバイアスとの和を計算し、
% yが0より大きいか小さいかで入力ベクトルを2つのクラスに分類するというものです。
% この重みベクトルを教師信号によって望みの形に逐次修正していくというのが、
% パーセプトロンの基本的な考え方です。

% 教師信号を与えた際にどのようにして重みベクトルを修正していくか？ですが、
% ここでヒンジ損失の概念と、いわゆる最急降下法とを用います。
% まず、ヒンジ損失については、
% 
% loss(w,x,t) = max(0, -tw'x)
% （w:重みベクトル、x:教師信号ベクトル、t:xの正解ラベルで1 or -1）
% 
% と表せます。これはどういう意味かというと、上記の識別関数の返す値w'xと
% 正解ラベルtの符号が同じなら、twxは正の値（つまり-twxは負の値）になります。
% 即ちその場合loss(w,x,t)は0を返します。言い換えると「識別関数が正しい符号の
% 値を返したので損失はゼロ」ということになります。
% 逆に、w'xとtの符号が異なるなら、loss(w,x,t)は-tw'xを返します。言い換えると、
% |w'x|という大きさの損失があり、修正せよということになります。
% 
% 次に最急降下法について。これは極めて単純で、上記の損失関数をwの関数とみなし、
% n->n+1と教師信号1事例分ステップが進むごとに損失関数をwで偏微分したものを
% wから引いて更新する、というものです。
% ちなみに偏微分というと難しそうに聞こえますが、実際に計算してみると
% 
% loss(w,x,t) = max(0, -tw'x)
% ↓
% ∂loss(w,x,t) = max(0, -tx)
% 
% となり、識別関数が正解（教師信号と同じ値）を返したら何もせず、
% 間違いを返したらtxを足すという意味になります。
% 
% 以上のポイントを踏まえて重みベクトルw(n)の更新式を書くと、
% 
% w(n+1) = w(n)　（教師信号と合致した場合）
% w(n+1) = w(n) + ηtx　（合致しない場合）
% （η：学習係数）
% 
% のように表せます。これを適当なループ変数のもとで繰り返させて、
% 可能であれば打ち切り基準を設けて望ましい学習精度に達した時点で
% 打ち切らせるようにすれば、欲しい重みベクトルwが手に入ります。
% 
% なお、w'x + b = 0が分離超平面です。w' = (m,n)であれば、
% mx + ny + b = 0なる直線が該当します。

% バイアスbについては、以下の更新式を用います。
% 
% b(n+1) = b(n) + ηtR^2
% （R：max(||xi||)、教師信号のノルムの最大値）
% 
% ただし、R^2だと過学習になる傾向があるようなので、
% このサンプルではRとしています。

%%
%%%%%%%%%%%%%%%%%
% 教師信号の設定 %
%%%%%%%%%%%%%%%%%
% ones関数で全要素1の行列を適当に作り、そこにrand関数でばらつきを与えています。
% cをrand関数に乗じることで、ばらつきの大きさを変えることができます。
% 各信号のxyz座標を列ベクトルで表しています。
% 行方向にそれぞれのxyz座標を並べていくイメージです。

c=8;

x1_list=1*ones(3,15)+c*rand(3,15);
x2_list=-1*ones(3,15)-c*rand(3,15);
c1=size(x1_list,2); % x1_listの要素数
c2=size(x2_list,2); % x2_listの要素数
clength=c1+c2; % 全要素数：この後毎回参照することになります。

% 正解信号：x1とx2とで分離したいので、対応するインデックスに1と-1を割り振ります。
x_list=[x1_list x2_list]; % x1_listとx2_listを行方向に並べてまとめます。
t_list=[ones(c1,1);-1*ones(c2,1)]; % 正解信号をx1:1, x2:-1として列ベクトルにまとめます。

% バイアス学習のためのRを求めます。
Rt=zeros(clength,1);

for i=1:clength
    Rt(i)=norm(x_list(:,i));
end;

R=max(Rt);

%%
%%%%%%%%%%%%%%%%%
% 各変数の初期化 %
%%%%%%%%%%%%%%%%%
% zeros関数で全要素0のベクトルを作る。

wvec=[0;0;0]; % 初期重みベクトル
bias=0; % 初期バイアス
loop=1000; % 訓練の繰り返し回数

%%
%%%%%%%%%%%%%%%%%%%%%
% 重みベクトルの学習 %
%%%%%%%%%%%%%%%%%%%%%
% シンプルにloop回だけ学習させています。
% 学習誤差を打ち切り条件にしてwhile文で回しても良いです。

for j=1:loop
    for i=1:clength
        [wvec,bias]=tjo_train(wvec,bias,R,x_list(:,i),t_list(i)); % 学習関数は別
    end;
    j=j+1;
end;

%%
%%%%%%%%%%%%%%%%%%%%%
% 入力ベクトルの判定 %
%%%%%%%%%%%%%%%%%%%%%

% 後は識別関数に代入。
[out,yvec]=tjo_predict(wvec,bias,xvec);

% 識別関数の返値の正負（もしくはゼロ）によって結果をコマンドラインを表示。
if(out==1)
    fprintf(1,'Group 1\n\n');
elseif(out==-1)
    fprintf(1,'Group 2\n\n');
else
    fprintf(1,'On the border\n\n');
end;

%%
%%%%%%%%%%%%%%%%%%%%%
% 可視化（プロット） %
%%%%%%%%%%%%%%%%%%%%%
% Matlab最大の武器である可視化パート。
% コメントのないところは適宜Matlabヘルプをご参照下さい。

a=wvec(1);
b=wvec(2);
c=wvec(3);
d=bias;

[xx,yy]=meshgrid(-10:.1:10,-10:.1:10);
zz=-(a/c)*xx-(b/c)*yy-(d/c);
figure;
mesh(xx,yy,zz);hold on;
scatter3(x1_list(1,:),x1_list(2,:),x1_list(3,:),500,'ko');hold on;
scatter3(x2_list(1,:),x2_list(2,:),x2_list(3,:),500,'k+');hold on;
if(out==1)
    scatter3(xvec(1),xvec(2),xvec(3),500,'ro');
elseif(out==-1)
    scatter3(xvec(1),xvec(2),xvec(3),500,'r+');
else
    scatter3(xvec(1),xvec(2),xvec(3),500,'bo');
end;

xlim([-10 10]);ylim([-10 10]);zlim([-10 10]);

end